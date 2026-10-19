require "rails_helper"

RSpec.describe "費用入力のエラー表示", type: :request do
  let(:user) do
    User.create!(
      name: "入力確認ユーザー",
      email: "input-validation@example.com",
      password: "password",
      password_confirmation: "password"
    )
  end

  def item_attributes(name: "", amount: "", category: "moving")
    { name: name, amount: amount, category: category, status: "unchecked" }
  end

  it "費用名が空で金額を入力した場合は値を保持し、該当行の修正案内を表示する" do
    post cost_lists_path, params: {
      cost_list: {
        budget: 300_000,
        cost_items_attributes: { "0" => item_attributes(amount: 50_000) }
      }
    }

    expect(response).to have_http_status(:unprocessable_content)
    document = Nokogiri::HTML(response.body)
    expect(document.at_css("input[name='cost_list[budget]']")["value"]).to eq("300000")
    expect(document.at_css("input[name$='[amount]'][value='50000']")).to be_present
    expect(document.css("[role='alert']").text).to include("引っ越し業者費用", "1行目", "費用名を入力してください")
    expect(document.at_css("input[name$='[name]'][aria-invalid='true']")).to be_present
    expect(CostList.count).to eq(0)
  end

  it "両方空の行を無視し、費用名だけの行はゲストでも計算できる" do
    post cost_lists_path, params: {
      cost_list: {
        cost_items_attributes: {
          "0" => item_attributes,
          "1" => item_attributes(name: "金額確認中の費用")
        }
      }
    }

    expect(response).to redirect_to(result_cost_lists_path)
    follow_redirect!
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("金額確認中の費用")
  end

  it "予算や費用金額が不正な場合も入力フォームで原因を表示する" do
    post cost_lists_path, params: {
      cost_list: {
        budget: -1,
        cost_items_attributes: { "0" => item_attributes(name: "引っ越し業者費用", amount: -50_000) }
      }
    }

    expect(response).to have_http_status(:unprocessable_content)
    document = Nokogiri::HTML(response.body)
    expect(document.css("[role='alert']").text).to include("予算", "金額", "0以上")
    expect(document.at_css("input[name$='[amount]'][value='-50000']")).to be_present
  end

  it "保存済みリストの編集失敗で具体的な費用名エラーを表示し、入力を保持する" do
    cost_list = user.cost_lists.create!(title: "編集前のリスト")
    item = cost_list.cost_items.create!(item_attributes(name: "引っ越し業者費用", amount: 20_000))
    post login_path, params: { email: user.email, password: "password" }

    patch cost_list_path(cost_list), params: {
      cost_list: {
        title: "編集中のリスト",
        cost_items_attributes: { "0" => item_attributes(amount: 50_000).merge(id: item.id) }
      }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("費用名を入力してください", "編集中のリスト")
    expect(Nokogiri::HTML(response.body).at_css("input[name$='[amount]'][value='50000']")).to be_present
    expect(item.reload.amount).to eq(20_000)
  end

  it "結果画面で保存に失敗した場合は原因と入力内容を表示し、修正後に保存できる" do
    post login_path, params: { email: user.email, password: "password" }
    post cost_lists_path, params: {
      cost_list: {
        budget: 300_000,
        cost_items_attributes: { "0" => item_attributes(name: "引っ越し業者費用", amount: 50_000) }
      }
    }
    invalid_title = "あ" * 51

    post save_session_cost_lists_path, params: { cost_list: { title: invalid_title, memo: "保存前の判断メモ" } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("リスト名は50文字以内で入力してください", "保存前の判断メモ", invalid_title)
    expect(user.cost_lists.count).to eq(0)

    post save_session_cost_lists_path, params: { cost_list: { title: "修正したリスト名", memo: "保存前の判断メモ" } }

    expect(response).to redirect_to(mypage_path)
    expect(user.cost_lists.last.title).to eq("修正したリスト名")
    expect(user.cost_lists.last.cost_items.first.amount).to eq(50_000)
  end

  it "編集エラーの再表示でも削除予定の行を保持し、他の行の修正後に削除できる" do
    cost_list = user.cost_lists.create!(title: "削除と編集のリスト")
    removed_item = cost_list.cost_items.create!(item_attributes(name: "削除する費用", amount: 10_000))
    edited_item = cost_list.cost_items.create!(item_attributes(name: "修正する費用", amount: 20_000))
    post login_path, params: { email: user.email, password: "password" }

    patch cost_list_path(cost_list), params: {
      cost_list: {
        cost_items_attributes: {
          "0" => { id: removed_item.id, _destroy: "1" },
          "1" => item_attributes(amount: 50_000).merge(id: edited_item.id)
        }
      }
    }

    expect(response).to have_http_status(:unprocessable_content)
    document = Nokogiri::HTML(response.body)
    destroy_field = document.at_css("input[name='cost_list[cost_items_attributes][0][_destroy]']")
    expect(destroy_field["value"]).to eq("1")
    expect(document.css("[role='alert']").text).to include("引っ越し業者費用 1行目")

    # 再表示されたフォームの削除指定をそのまま送り、入力不備の行だけを直す。
    patch cost_list_path(cost_list), params: {
      cost_list: {
        cost_items_attributes: {
          "0" => { id: removed_item.id, _destroy: destroy_field["value"] },
          "1" => item_attributes(name: "修正した費用", amount: 50_000).merge(id: edited_item.id)
        }
      }
    }

    expect(response).to redirect_to(cost_list_path(cost_list))
    expect(CostItem.exists?(removed_item.id)).to be(false)
    expect(edited_item.reload.amount).to eq(50_000)
  end
end
