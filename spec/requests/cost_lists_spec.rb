require "rails_helper"

RSpec.describe "費用リスト", type: :request do
  describe "GET /cost_lists/new" do
    it "正常にアクセスできること" do
      get new_cost_list_path

      expect(response).to have_http_status(:ok)
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
      expect(response.body).to include("費用詳細")
      expect(response.body).to include("判断メモ")
      expect(response.body).to include("家賃")
    end
  end

  describe "PATCH /cost_lists/:id" do
    it "所有者であるログインユーザーが保存済み費用リストを更新できること" do
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
      expect(cost_item.amount).to eq(80_000)
      expect(cost_item.status).to eq("confirmed")
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
              memo: "駅から近い物件を優先する"
            }
          }
        end.not_to change(CostList, :count)

        expect(response).to redirect_to(login_path)
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
        expect(cost_list.title).to eq("引っ越し費用リスト")
        expect(cost_item.name).to eq("家賃")
        expect(cost_item.amount).to eq(70000)
      end
    end
  end
end
