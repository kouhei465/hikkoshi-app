require "rails_helper"

RSpec.describe CostList, type: :model do
  let(:user) do
    User.create!(
      name: "テストユーザー",
      email: "cost-list-test@example.com",
      password: "password",
      password_confirmation: "password"
    )
  end

  describe "バリデーション" do
    it "ユーザーが設定されている場合は有効になる" do
      cost_list = described_class.new(user: user, title: "テスト用費用リスト")

      expect(cost_list).to be_valid
    end

    it "ユーザーが設定されていない場合は無効になる" do
      cost_list = described_class.new(user: nil, title: "テスト用費用リスト")

      expect(cost_list).to be_invalid
    end

    it "タイトルが空の場合は無効になる" do
      cost_list = described_class.new(user: user, title: "")

      expect(cost_list).to be_invalid
    end

    it "タイトルが50文字を超える場合は無効になる" do
      cost_list = described_class.new(user: user, title: "あ" * 51)

      expect(cost_list).to be_invalid
    end
  end

  describe "関連付け" do
    it "ユーザーに属する" do
      association = described_class.reflect_on_association(:user)

      expect(association.macro).to eq(:belongs_to)
    end

    it "複数の費用項目を持つ" do
      association = described_class.reflect_on_association(:cost_items)

      expect(association.macro).to eq(:has_many)
    end

    it "費用リスト削除時に関連する費用項目も削除する設定になっている" do
      association = described_class.reflect_on_association(:cost_items)

      expect(association.options[:dependent]).to eq(:destroy)
    end

    it "費用リストを削除すると関連する費用項目も削除される" do
      cost_list = described_class.create!(
        user: user,
        title: "削除確認用リスト"
      )
      cost_item = cost_list.cost_items.create!(
        name: "家賃",
        category: :rent,
        amount: 70_000,
        status: :confirmed
      )

      cost_list.destroy!

      expect(CostItem.exists?(cost_item.id)).to be false
    end
  end

  describe "費用項目のネスト入力" do
    it "費用名と金額が両方空の場合は費用項目を作成しない" do
      cost_list = described_class.new(
        user: user,
        cost_items_attributes: {
          "0" => {
            name: "",
            amount: "",
            category: "rent",
            status: "unchecked",
            _destroy: "0"
          }
        }
      )

      expect(cost_list.cost_items).to be_empty
    end

    it "費用名が入力されている場合は費用項目を作成する" do
      cost_list = described_class.new(
        user: user,
        cost_items_attributes: {
          "0" => {
            name: "家賃",
            amount: "",
            category: "rent",
            status: "unchecked",
            _destroy: "0"
          }
        }
      )

      expect(cost_list.cost_items.size).to eq(1)
      expect(cost_list.cost_items.first.name).to eq("家賃")
    end

    it "ネストされた費用項目を削除できる" do
      cost_list = described_class.create!(
        user: user,
        title: "ネスト削除確認用リスト"
      )
      cost_item = cost_list.cost_items.create!(
        name: "家賃",
        category: :rent,
        amount: 70_000,
        status: :confirmed
      )

      cost_list.update!(
        cost_items_attributes: {
          "0" => {
            id: cost_item.id,
            _destroy: "1"
          }
        }
      )

      expect(CostItem.exists?(cost_item.id)).to be false
    end
  end
end
