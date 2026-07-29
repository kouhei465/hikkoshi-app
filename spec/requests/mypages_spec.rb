require "rails_helper"

RSpec.describe "マイページ", type: :request do
  describe "GET /mypage" do
    context "未ログインの場合" do
      it "ログインページにリダイレクトされること" do
        get mypage_path

        expect(response).to redirect_to(login_path)
        expect(flash[:alert]).to eq("ログインしてください")
      end
    end

    context "ログイン済みの場合" do
      it "複数の費用リストと各操作への導線が表示されること" do
        user = User.create!(
          name: "一覧テストユーザー",
          email: "mypage@example.com",
          password: "password",
          password_confirmation: "password"
        )
        first_cost_list = user.cost_lists.create!(title: "A物件の費用")
        second_cost_list = user.cost_lists.create!(title: "B物件の費用")

        post login_path, params: {
          email: user.email,
          password: "password"
        }

        get mypage_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("A物件の費用")
        expect(response.body).to include("B物件の費用")
        expect(response.body).to include("詳細を見る")
        expect(response.body).to include("編集する")
        expect(response.body).to include("名前を変更")
        expect(response.body).to include("削除する")
        expect(response.body).to include("ユーザー情報を編集する")
        expect(response.body).to include(edit_mypage_path)
        expect(response.body).to include(update_title_cost_list_path(first_cost_list))
        expect(response.body).to include(update_title_cost_list_path(second_cost_list))

        document = Nokogiri::HTML(response.body)
        compare_form = document.at_css(
          "form[action='#{compare_cost_lists_path}'][method='get']"
        )
        checkboxes = document.xpath(
          "//input[@type='checkbox' and @name='cost_list_ids[]']"
        )
        modal_ids = response.body.scan(/id="(rename-cost-list-modal-\d+)"/).flatten

        expect(compare_form).to be_present
        expect(compare_form["id"]).to eq("cost-list-compare-form")
        expect(checkboxes.map { |checkbox| checkbox["value"] }).to contain_exactly(
          first_cost_list.id.to_s,
          second_cost_list.id.to_s
        )
        expect(checkboxes).to all(
          satisfy { |checkbox| checkbox["form"] == "cost-list-compare-form" }
        )
        expect(document.text).to include("比較する費用リストを2件選択してください。")
        expect(compare_form.at_xpath(
          ".//button[@type='submit' and normalize-space()='選択した2件を比較する']"
        )).to be_present
        expect(modal_ids).to contain_exactly(
          "rename-cost-list-modal-#{first_cost_list.id}",
          "rename-cost-list-modal-#{second_cost_list.id}"
        )
      end

      it "保存済みリストが2件未満の場合は案内を表示して比較ボタンを無効にすること" do
        user = User.create!(
          name: "比較案内テストユーザー",
          email: "mypage-compare-guide@example.com",
          password: "password",
          password_confirmation: "password"
        )
        user.cost_lists.create!(title: "A物件の費用")

        post login_path, params: { email: user.email, password: "password" }

        get mypage_path

        document = Nokogiri::HTML(response.body)
        disabled_button = document.at_xpath(
          "//button[@type='submit' and normalize-space()='選択した2件を比較する' and @disabled]"
        )

        expect(response.body).to include("比較するには費用リストを2件以上保存してください。")
        expect(disabled_button).to be_present
      end
    end
  end

  describe "GET /mypage/edit" do
    context "未ログインの場合" do
      it "ログインページにリダイレクトされること" do
        get edit_mypage_path

        expect(response).to redirect_to(login_path)
        expect(flash[:alert]).to eq("ログインしてください")
      end
    end

    context "ログイン済みの場合" do
      it "現在のメールアドレスと変更フォームを表示すること" do
        user = User.create!(
          name: "編集画面テストユーザー",
          email: "edit-mypage@example.com",
          password: "password",
          password_confirmation: "password"
        )
        post login_path, params: { email: user.email, password: "password" }

        get edit_mypage_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("現在のメールアドレス")
        expect(response.body).to include(user.email)
        expect(response.body).to include("新しいメールアドレス")
        expect(response.body).to include("現在のパスワード")
      end
    end
  end

  describe "PATCH /mypage" do
    let(:user) do
      User.create!(
        name: "メール変更ユーザー",
        email: "current@example.com",
        password: "password",
        password_confirmation: "password"
      )
    end

    let(:valid_params) do
      {
        user: {
          email: "changed@example.com",
          current_password: "password"
        }
      }
    end

    context "未ログインの場合" do
      it "メールアドレスを変更せずログインページにリダイレクトすること" do
        original_email = user.email

        patch mypage_path, params: valid_params

        expect(response).to redirect_to(login_path)
        expect(flash[:alert]).to eq("ログインしてください")
        expect(user.reload.email).to eq(original_email)
      end
    end

    context "ログイン済みの場合" do
      before do
        post login_path, params: { email: user.email, password: "password" }
      end

      it "正しい現在のパスワードでメールアドレスを変更すること" do
        patch mypage_path, params: valid_params

        expect(response).to redirect_to(mypage_path)
        expect(flash[:notice]).to eq("メールアドレスを変更しました")
        expect(user.reload.email).to eq("changed@example.com")
      end

      it "間違った現在のパスワードでは変更せず入力メールを保持すること" do
        submitted_email = " Wrong@Example.COM "

        patch mypage_path, params: {
          user: {
            email: submitted_email,
            current_password: "wrong-password"
          }
        }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("現在のパスワードが正しくありません")
        expect(Nokogiri::HTML(response.body).at_css("input[name='user[email]']")["value"]).to eq(
          submitted_email
        )
        expect(user.reload.email).to eq("current@example.com")
      end

      it "現在のパスワードが空の場合は変更しないこと" do
        patch mypage_path, params: {
          user: {
            email: "changed@example.com",
            current_password: ""
          }
        }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("現在のパスワードを入力してください")
        expect(user.reload.email).to eq("current@example.com")
      end

      it "新しいメールアドレスが空の場合は変更しないこと" do
        patch mypage_path, params: {
          user: {
            email: "   ",
            current_password: "password"
          }
        }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("新しいメールアドレスを入力してください")
        expect(user.reload.email).to eq("current@example.com")
      end

      it "他のユーザーが使用中のメールアドレスでは変更しないこと" do
        User.create!(
          name: "登録済みメールユーザー",
          email: "Used@Example.COM",
          password: "password",
          password_confirmation: "password"
        )

        patch mypage_path, params: {
          user: {
            email: "used@example.com",
            current_password: "password"
          }
        }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("そのメールアドレスは使用できません")
        expect(user.reload.email).to eq("current@example.com")
      end

      it "現在と同じメールアドレスでは変更しないこと" do
        patch mypage_path, params: {
          user: {
            email: "current@example.com",
            current_password: "password"
          }
        }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("現在と同じメールアドレスです")
        expect(user.reload.email).to eq("current@example.com")
      end

      it "大文字・小文字だけが違う現在のメールアドレスでは変更しないこと" do
        patch mypage_path, params: {
          user: {
            email: "CURRENT@EXAMPLE.COM",
            current_password: "password"
          }
        }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("現在と同じメールアドレスです")
        expect(user.reload.email).to eq("current@example.com")
      end

      it "メールアドレスの前後の空白を除去して保存すること" do
        patch mypage_path, params: {
          user: {
            email: "  trimmed@example.com  ",
            current_password: "password"
          }
        }

        expect(response).to redirect_to(mypage_path)
        expect(user.reload.email).to eq("trimmed@example.com")
      end

      it "メールアドレスを小文字に変換して保存すること" do
        patch mypage_path, params: {
          user: {
            email: "Changed@Example.COM",
            current_password: "password"
          }
        }

        expect(response).to redirect_to(mypage_path)
        expect(user.reload.email).to eq("changed@example.com")
      end

      it "nameやidなど許可していない属性を変更しないこと" do
        original_id = user.id
        original_name = user.name

        patch mypage_path, params: {
          user: {
            id: original_id + 1,
            name: "変更されない名前",
            email: "permitted@example.com",
            current_password: "password"
          }
        }

        user.reload

        expect(response).to redirect_to(mypage_path)
        expect(user.id).to eq(original_id)
        expect(user.name).to eq(original_name)
        expect(user.email).to eq("permitted@example.com")
      end

      it "他のユーザーを示すidが送信されてもログインユーザーだけを変更すること" do
        other_user = User.create!(
          name: "変更されないユーザー",
          email: "other@example.com",
          password: "password",
          password_confirmation: "password"
        )
        other_user_attributes = other_user.attributes

        patch mypage_path, params: {
          id: other_user.id,
          user: {
            id: other_user.id,
            email: "current-user-only@example.com",
            current_password: "password"
          }
        }

        expect(response).to redirect_to(mypage_path)
        expect(user.reload.email).to eq("current-user-only@example.com")
        expect(other_user.reload.attributes).to eq(other_user_attributes)
      end

      it "変更成功後もログイン状態を維持すること" do
        patch mypage_path, params: valid_params

        get mypage_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("マイページ")
      end
    end
  end
end
