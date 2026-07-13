require "rails_helper"

RSpec.describe "ユーザー登録", type: :request do
  describe "GET /users/new" do
    it "正常にアクセスできること" do
      get new_user_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /users" do
    context "入力内容が正しい場合" do
      it "ユーザー登録が成功し、自動ログインされること" do
        expect do
          post users_path, params: {
            user: {
              name: "新規ユーザー",
              email: "new-user@example.com",
              password: "password",
              password_confirmation: "password"
            }
          }
        end.to change(User, :count).by(1)

        expect(response).to redirect_to(mypage_path)

        user = User.find_by(email: "new-user@example.com")

        expect(user).to be_present
        expect(user.name).to eq("新規ユーザー")

        get mypage_path

        expect(response).to have_http_status(:ok)
      end
    end

    context "入力内容が不正な場合" do
      it "ユーザー登録に失敗し、ログイン状態にならないこと" do
        expect do
          post users_path, params: {
            user: {
              name: "新規ユーザー",
              email: "invalid-user@example.com",
              password: "password",
              password_confirmation: "different-password"
            }
          }
        end.not_to change(User, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(User.find_by(email: "invalid-user@example.com")).to be_nil

        get mypage_path

        expect(response).to redirect_to(login_path)
      end
    end

    context "ゲストが費用データを入力済みの場合" do
      it "ユーザー登録と同時に費用リストと費用項目が保存されること" do
        post cost_lists_path, params: {
          cost_list: {
            budget: 300_000,
            cost_items_attributes: {
              "0" => {
                name: "家賃",
                category: "rent",
                amount: 70_000,
                status: "estimated"
              }
            }
          }
        }

        expect(response).to redirect_to(result_cost_lists_path)

        post save_session_cost_lists_path, params: {
          cost_list: {
            title: "A物件の費用",
            memo: "駅から近い物件を優先する"
          }
        }

        expect(response).to redirect_to(login_path)

        user_params = {
          user: {
            name: "ゲスト登録ユーザー",
            email: "guest-register@example.com",
            password: "password",
            password_confirmation: "password"
          }
        }
        user_count = User.count
        cost_list_count = CostList.count
        cost_item_count = CostItem.count

        post users_path, params: user_params

        expect(User.count).to eq(user_count + 1)
        expect(CostList.count).to eq(cost_list_count + 1)
        expect(CostItem.count).to eq(cost_item_count + 1)
        expect(response).to redirect_to(mypage_path)

        user = User.find_by!(email: "guest-register@example.com")
        cost_list = user.cost_lists.last
        cost_item = cost_list.cost_items.first

        expect(cost_list.title).to eq("A物件の費用")
        expect(cost_list.budget).to eq(300_000)
        expect(cost_list.memo).to eq("駅から近い物件を優先する")
        expect(cost_item.name).to eq("家賃")
        expect(cost_item.category).to eq("rent")
        expect(cost_item.amount).to eq(70_000)
        expect(cost_item.status).to eq("estimated")

        get result_cost_lists_path

        expect(response).to redirect_to(new_cost_list_path)
      end
    end
  end
end
