require "rails_helper"

RSpec.describe "費用リスト", type: :request do
  describe "GET /cost_lists/new" do
    it "正常にアクセスできること" do
      get new_cost_list_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("リスト名")
    end
  end

  describe "POST /cost_lists" do
    it "費用リストの入力内容を送信後、結果画面にリダイレクトすること" do
      post cost_lists_path, params: {
        cost_list: {
          budget: 300000,
          cost_items_attributes: {
            "0" => {
              name: "家賃",
              category: "rent",
              amount: 70000,
              status: "estimated"
            }
          }
        }
      }

      expect(response).to redirect_to(result_cost_lists_path)
    end
  end

  describe "GET /cost_lists/result" do
    it "セッションに費用リストの入力内容がない場合、入力画面にリダイレクトすること" do
      get result_cost_lists_path

      expect(response).to redirect_to(new_cost_list_path)
    end

    it "保存用の任意のリスト名入力欄を表示すること" do
      post cost_lists_path, params: {
        cost_list: {
          budget: 300000,
          cost_items_attributes: {}
        }
      }

      get result_cost_lists_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("リスト名（任意）")
      expect(response.body).to include("例：A物件の費用")
      expect(response.body).to include("未入力の場合は「引っ越し費用リスト」として保存されます。")
      expect(response.body).to include(save_session_cost_lists_path)
    end
  end

  describe "GET /cost_lists/:id" do
    it "所有者であるログインユーザーが保存済み費用リストの詳細画面を表示できること" do
      user = User.create!(
        name: "テストユーザー",
        email: "show@example.com",
        password: "password",
        password_confirmation: "password"
      )
      cost_list = user.cost_lists.create!(
        title: "引っ越し費用リスト",
        budget: 300000,
        memo: "駅から近い物件を優先する"
      )
      cost_list.cost_items.create!(
        name: "家賃",
        category: "rent",
        amount: 70000,
        status: "estimated"
      )

      post login_path, params: {
        email: user.email,
        password: "password"
      }

      get cost_list_path(cost_list)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("引っ越し費用リスト")
      expect(response.body).to include("費用詳細")
      expect(response.body).to include("判断メモ")
      expect(response.body).to include("家賃")
    end
  end

  describe "GET /cost_lists/:id/edit" do
    it "所有者の編集画面にリスト名と現在のタイトルを表示すること" do
      user = User.create!(
        name: "編集画面テストユーザー",
        email: "edit-view@example.com",
        password: "password",
        password_confirmation: "password"
      )
      cost_list = user.cost_lists.create!(title: "A物件の費用", budget: 300000)

      post login_path, params: { email: user.email, password: "password" }

      get edit_cost_list_path(cost_list)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("リスト名")
      expect(response.body).to include("A物件の費用")
    end
  end

  describe "PATCH /cost_lists/:id" do
    it "所有者がタイトル・予算・費用項目をまとめて更新できること" do
      user = User.create!(
        name: "更新テストユーザー",
        email: "update@example.com",
        password: "password",
        password_confirmation: "password"
      )
      cost_list = user.cost_lists.create!(
        title: "引っ越し費用リスト",
        budget: 300000,
        memo: "更新前のメモ"
      )
      cost_item = cost_list.cost_items.create!(
        name: "家賃",
        category: "rent",
        amount: 70000,
        status: "estimated"
      )

      post login_path, params: {
        email: user.email,
        password: "password"
      }

      patch cost_list_path(cost_list), params: {
        cost_list: {
          title: "更新後の費用リスト",
          budget: 350_000,
          cost_items_attributes: {
            "0" => {
              id: cost_item.id,
              name: "家賃",
              category: "rent",
              amount: 80_000,
              status: "confirmed"
            }
          }
        }
      }

      expect(response).to redirect_to(cost_list_path(cost_list))

      cost_list.reload
      cost_item.reload

      expect(cost_list.budget).to eq(350_000)
      expect(cost_list.title).to eq("更新後の費用リスト")
      expect(cost_item.amount).to eq(80_000)
      expect(cost_item.status).to eq("confirmed")
    end

    it "タイトルが空欄の場合は更新しないこと" do
      user = User.create!(
        name: "空タイトル更新テストユーザー",
        email: "blank-title-update@example.com",
        password: "password",
        password_confirmation: "password"
      )
      cost_list = user.cost_lists.create!(title: "変更前のリスト名", budget: 300000)

      post login_path, params: { email: user.email, password: "password" }

      patch cost_list_path(cost_list), params: {
        cost_list: { title: "", budget: 400000 }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(cost_list.reload.title).to eq("変更前のリスト名")
      expect(cost_list.budget).to eq(300000)
    end

    it "他人の費用リストを更新できないこと" do
      owner = User.create!(
        name: "編集対象の所有者",
        email: "edit-owner@example.com",
        password: "password",
        password_confirmation: "password"
      )
      other_user = User.create!(
        name: "編集を試みるユーザー",
        email: "edit-other@example.com",
        password: "password",
        password_confirmation: "password"
      )
      cost_list = owner.cost_lists.create!(title: "所有者のリスト", budget: 300000)

      post login_path, params: { email: other_user.email, password: "password" }

      patch cost_list_path(cost_list), params: {
        cost_list: { title: "他人が変更した名前", budget: 400000 }
      }

      expect(response).to have_http_status(:not_found)
      expect(cost_list.reload.title).to eq("所有者のリスト")
      expect(cost_list.budget).to eq(300000)
    end
  end

  describe "PATCH /cost_lists/:id/update_memo" do
    it "所有者であるログインユーザーが保存済み費用リストの判断メモを更新できること" do
      user = User.create!(
        name: "メモ更新ユーザー",
        email: "memo@example.com",
        password: "password",
        password_confirmation: "password"
      )
      cost_list = user.cost_lists.create!(
        title: "引っ越し費用リスト",
        budget: 300000,
        memo: "更新前のメモ"
      )

      post login_path, params: {
        email: user.email,
        password: "password"
      }

      patch update_memo_cost_list_path(cost_list), params: {
        cost_list: {
          memo: "駅から近い物件を優先する"
        }
      }

      expect(response).to redirect_to(cost_list_path(cost_list))

      cost_list.reload

      expect(cost_list.memo).to eq("駅から近い物件を優先する")
    end
  end

  describe "POST /cost_lists/save_session" do
    context "未ログインの場合" do
      it "費用リストを保存せず、ログイン画面にリダイレクトすること" do
        post cost_lists_path, params: {
          cost_list: {
            budget: 300000,
            cost_items_attributes: {
              "0" => {
                name: "家賃",
                category: "rent",
                amount: 70000,
                status: "estimated"
              }
            }
          }
        }

        expect do
          post save_session_cost_lists_path, params: {
            cost_list: {
              title: "ゲストの費用リスト",
              memo: "駅から近い物件を優先する"
            }
          }
        end.not_to change(CostList, :count)

        expect(response).to redirect_to(login_path)
      end

      it "入力したタイトルをユーザー登録後の保存に引き継ぐこと" do
        post cost_lists_path, params: {
          cost_list: {
            budget: 300000,
            cost_items_attributes: {}
          }
        }

        post save_session_cost_lists_path, params: {
          cost_list: {
            title: "ゲストが付けたリスト名",
            memo: "登録後も保存するメモ"
          }
        }

        expect(response).to redirect_to(login_path)

        expect do
          post users_path, params: {
            user: {
              name: "ゲスト登録ユーザー",
              email: "guest-title@example.com",
              password: "password",
              password_confirmation: "password"
            }
          }
        end.to change(CostList, :count).by(1)

        cost_list = User.find_by!(email: "guest-title@example.com").cost_lists.last

        expect(cost_list.title).to eq("ゲストが付けたリスト名")
        expect(cost_list.memo).to eq("登録後も保存するメモ")
      end
    end

    context "ログイン済みの場合" do
      it "費用リストと費用項目を保存し、マイページにリダイレクトすること" do
        user = User.create!(
          name: "テストユーザー",
          email: "test@example.com",
          password: "password",
          password_confirmation: "password"
        )

        post login_path, params: {
          email: user.email,
          password: "password"
        }

        post cost_lists_path, params: {
          cost_list: {
            budget: 300000,
            cost_items_attributes: {
              "0" => {
                name: "家賃",
                category: "rent",
                amount: 70000,
                status: "estimated"
              }
            }
          }
        }

        expect do
          post save_session_cost_lists_path, params: {
            cost_list: {
              title: "A物件の費用",
              memo: "駅から近い物件を優先する"
            }
          }
        end.to change(CostList, :count).by(1)
          .and change(CostItem, :count).by(1)

        expect(response).to redirect_to(mypage_path)

        cost_list = CostList.last
        cost_item = cost_list.cost_items.first

        expect(cost_list.user).to eq(user)
        expect(cost_list.budget).to eq(300000)
        expect(cost_list.memo).to eq("駅から近い物件を優先する")
        expect(cost_list.title).to eq("A物件の費用")
        expect(cost_item.name).to eq("家賃")
        expect(cost_item.amount).to eq(70000)
      end

      it "タイトルが空の場合はデフォルトタイトルで保存すること" do
        user = User.create!(
          name: "デフォルトタイトル確認ユーザー",
          email: "default-title@example.com",
          password: "password",
          password_confirmation: "password"
        )

        post login_path, params: {
          email: user.email,
          password: "password"
        }

        post cost_lists_path, params: {
          cost_list: {
            budget: 300000,
            cost_items_attributes: {}
          }
        }

        expect do
          post save_session_cost_lists_path, params: {
            cost_list: { title: "", memo: "" }
          }
        end.to change(CostList, :count).by(1)

        expect(user.cost_lists.last.title).to eq("引っ越し費用リスト")
      end

      it "タイトルの前後の空白を取り除いて保存すること" do
        user = User.create!(
          name: "空白除去確認ユーザー",
          email: "trim-title@example.com",
          password: "password",
          password_confirmation: "password"
        )

        post login_path, params: {
          email: user.email,
          password: "password"
        }

        post cost_lists_path, params: {
          cost_list: {
            budget: 300000,
            cost_items_attributes: {}
          }
        }

        post save_session_cost_lists_path, params: {
          cost_list: { title: "  A物件の費用  ", memo: "" }
        }

        expect(user.cost_lists.last.title).to eq("A物件の費用")
      end
    end
  end

  describe "GET /cost_lists/compare" do
    context "未ログインの場合" do
      it "ログイン画面にリダイレクトすること" do
        get compare_cost_lists_path, params: { cost_list_ids: [ 1, 2 ] }

        expect(response).to redirect_to(login_path)
      end
    end

    context "ログイン済みの場合" do
      let(:user) do
        User.create!(
          name: "比較テストユーザー",
          email: "compare@example.com",
          password: "password",
          password_confirmation: "password"
        )
      end
      let(:first_cost_list) do
        user.cost_lists.create!(
          title: "A物件の費用",
          budget: 400_000
        )
      end
      let(:second_cost_list) do
        user.cost_lists.create!(
          title: "B物件の費用",
          budget: 180_000
        )
      end

      before do
        first_cost_list.cost_items.create!(
          name: "家賃",
          category: "rent",
          amount: 100_000,
          status: "confirmed"
        )
        first_cost_list.cost_items.create!(
          name: "引っ越し業者費用",
          category: "moving",
          amount: 50_000,
          status: "estimated"
        )
        second_cost_list.cost_items.create!(
          name: "冷蔵庫",
          category: "furniture",
          amount: 180_000,
          status: "confirmed"
        )
        second_cost_list.cost_items.create!(
          name: "雑費",
          category: "other",
          amount: 40_000,
          status: "estimated"
        )

        post login_path, params: { email: user.email, password: "password" }
      end

      it "自分の2件の費用リストについて総額・予算差・カテゴリ別内訳・安い方を比較できること" do
        get compare_cost_lists_path,
            params: { cost_list_ids: [ second_cost_list.id, first_cost_list.id ] }

        expect(response).to have_http_status(:ok)

        document = Nokogiri::HTML(response.body)
        headers = document.css("table thead th").map { |header| header.text.strip }

        expect(headers).to eq([ "比較項目", "B物件の費用", "A物件の費用" ])
        expect(table_row_values(document, "費用合計")).to eq([ "220,000円", "150,000円" ])
        expect(table_row_values(document, "予算との差")).to eq(
          [ "予算超過：40,000円", "予算内：残り250,000円" ]
        )
        expect(table_row_values(document, "賃貸費用")).to eq([ "0円", "100,000円" ])
        expect(table_row_values(document, "引っ越し業者費用")).to eq([ "0円", "50,000円" ])
        expect(table_row_values(document, "家具家電費用")).to eq([ "180,000円", "0円" ])
        expect(table_row_values(document, "その他費用")).to eq([ "40,000円", "0円" ])
        expect(document.text).to include("A物件の費用の方が70,000円安いです。")
      end

      it "予算が未入力の費用リストを0円の予算として表示しないこと" do
        first_cost_list.update!(budget: nil)

        get compare_cost_lists_path,
            params: { cost_list_ids: [ first_cost_list.id, second_cost_list.id ] }

        document = Nokogiri::HTML(response.body)

        expect(table_row_values(document, "予算").first).to eq("予算未入力")
        expect(table_row_values(document, "予算との差").first).to eq("予算未入力")
      end

      it "選択が0件の場合はマイページにリダイレクトすること" do
        get compare_cost_lists_path

        expect(response).to redirect_to(mypage_path)
        expect(flash[:alert]).to eq("比較する費用リストを2件選択してください")
      end

      it "選択が1件の場合はマイページにリダイレクトすること" do
        get compare_cost_lists_path, params: { cost_list_ids: [ first_cost_list.id ] }

        expect(response).to redirect_to(mypage_path)
        expect(flash[:alert]).to eq("比較する費用リストを2件選択してください")
      end

      it "選択が3件以上の場合はマイページにリダイレクトすること" do
        third_cost_list = user.cost_lists.create!(title: "C物件の費用")

        get compare_cost_lists_path,
            params: {
              cost_list_ids: [
                first_cost_list.id,
                second_cost_list.id,
                third_cost_list.id
              ]
            }

        expect(response).to redirect_to(mypage_path)
        expect(flash[:alert]).to eq("比較する費用リストを2件選択してください")
      end

      it "同じIDを2回送った場合はマイページにリダイレクトすること" do
        get compare_cost_lists_path,
            params: { cost_list_ids: [ first_cost_list.id, first_cost_list.id ] }

        expect(response).to redirect_to(mypage_path)
        expect(flash[:alert]).to eq("比較する費用リストを2件選択してください")
      end

      it "他人の費用リストが含まれる場合はマイページにリダイレクトすること" do
        other_user = User.create!(
          name: "比較対象外ユーザー",
          email: "compare-other@example.com",
          password: "password",
          password_confirmation: "password"
        )
        other_cost_list = other_user.cost_lists.create!(title: "他人の費用リスト")

        get compare_cost_lists_path,
            params: { cost_list_ids: [ first_cost_list.id, other_cost_list.id ] }

        expect(response).to redirect_to(mypage_path)
        expect(flash[:alert]).to eq("比較対象の費用リストを確認できませんでした")
      end

      it "存在しないIDが含まれる場合はマイページにリダイレクトすること" do
        nonexistent_id = CostList.maximum(:id).to_i + 1

        get compare_cost_lists_path,
            params: { cost_list_ids: [ first_cost_list.id, nonexistent_id ] }

        expect(response).to redirect_to(mypage_path)
        expect(flash[:alert]).to eq("比較対象の費用リストを確認できませんでした")
      end
    end
  end

  describe "PATCH /cost_lists/:id/update_title" do
    let(:owner) do
      User.create!(
        name: "名前変更ユーザー",
        email: "update-title@example.com",
        password: "password",
        password_confirmation: "password"
      )
    end
    let(:cost_list) do
      owner.cost_lists.create!(
        title: "変更前のリスト名",
        budget: 300000,
        memo: "変更前のメモ"
      )
    end

    it "所有者がリスト名を変更できること" do
      post login_path, params: { email: owner.email, password: "password" }

      patch update_title_cost_list_path(cost_list), params: {
        cost_list: { title: "変更後のリスト名" }
      }

      expect(response).to redirect_to(mypage_path)
      expect(flash[:notice]).to eq("リスト名を変更しました")
      expect(cost_list.reload.title).to eq("変更後のリスト名")
    end

    it "タイトル以外の属性を変更しないこと" do
      post login_path, params: { email: owner.email, password: "password" }

      patch update_title_cost_list_path(cost_list), params: {
        cost_list: {
          title: "変更後のリスト名",
          budget: 500000,
          memo: "変更後のメモ"
        }
      }

      cost_list.reload

      expect(cost_list.title).to eq("変更後のリスト名")
      expect(cost_list.budget).to eq(300000)
      expect(cost_list.memo).to eq("変更前のメモ")
    end

    it "タイトルが空欄の場合は変更しないこと" do
      post login_path, params: { email: owner.email, password: "password" }

      patch update_title_cost_list_path(cost_list), params: {
        cost_list: { title: "" }
      }

      expect(response).to redirect_to(mypage_path)
      expect(flash[:alert]).to eq("リスト名を変更できませんでした")
      expect(cost_list.reload.title).to eq("変更前のリスト名")
    end

    it "他人の費用リストを変更できないこと" do
      other_user = User.create!(
        name: "他ユーザー",
        email: "other-update-title@example.com",
        password: "password",
        password_confirmation: "password"
      )
      post login_path, params: { email: other_user.email, password: "password" }

      patch update_title_cost_list_path(cost_list), params: {
        cost_list: { title: "他人が変更した名前" }
      }

      expect(response).to have_http_status(:not_found)
      expect(cost_list.reload.title).to eq("変更前のリスト名")
    end
  end

  describe "DELETE /cost_lists/:id" do
    it "所有者であるログインユーザーが費用リストを削除できること" do
      user = User.create!(
        name: "削除テストユーザー",
        email: "destroy@example.com",
        password: "password",
        password_confirmation: "password"
      )
      cost_list = user.cost_lists.create!(title: "削除する費用リスト")

      post login_path, params: {
        email: user.email,
        password: "password"
      }

      expect do
        delete cost_list_path(cost_list)
      end.to change(CostList, :count).by(-1)

      expect(response).to redirect_to(mypage_path)
      expect(flash[:notice]).to eq("費用リストを削除しました")
    end

    it "他人の費用リストを削除できないこと" do
      owner = User.create!(
        name: "所有者",
        email: "owner@example.com",
        password: "password",
        password_confirmation: "password"
      )
      other_user = User.create!(
        name: "他ユーザー",
        email: "other@example.com",
        password: "password",
        password_confirmation: "password"
      )
      cost_list = owner.cost_lists.create!(title: "所有者の費用リスト")

      post login_path, params: {
        email: other_user.email,
        password: "password"
      }

      expect do
        delete cost_list_path(cost_list)
      end.not_to change(CostList, :count)

      expect(response).to have_http_status(:not_found)
      expect(CostList.exists?(cost_list.id)).to be true
    end
  end

  def table_row_values(document, heading)
    row = document.css("table tbody tr").find do |table_row|
      table_row.at_css("th").text.strip == heading
    end

    row.css("td").map { |cell| cell.text.strip }
  end
end
