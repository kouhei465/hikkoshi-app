require "rails_helper"

RSpec.describe "費用項目", type: :request do
  describe "PATCH /cost_lists/:cost_list_id/cost_items/:id/update_status" do
    it "所有者であるログインユーザーが費用項目のステータスを更新できること" do
      user = User.create!(
        name: "ステータス更新ユーザー",
        email: "status@example.com",
        password: "password",
        password_confirmation: "password"
      )
      cost_list = user.cost_lists.create!(
        title: "引っ越し費用リスト",
        budget: 300000,
        memo: "テスト用メモ"
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

      patch update_status_cost_list_cost_item_path(cost_list, cost_item), params: {
        cost_item: {
          status: "confirmed"
        }
      }

      expect(response).to redirect_to(cost_list_path(cost_list))

      cost_item.reload

      expect(cost_item.status).to eq("confirmed")
    end
  end
end
