require "rails_helper"

RSpec.describe CostItem, type: :model do
  let(:user) do
    User.create!(
      name: "テストユーザー",
      email: "cost-item-test@example.com",
      password: "password",
      password_confirmation: "password"
    )
  end

  let(:cost_list) do
    CostList.create!(
      user: user,
      title: "テスト用費用リスト"
    )
  end

  describe "バリデーション" do
    it "有効な属性の場合は保存できる" do
      cost_item = described_class.new(
        cost_list: cost_list,
        name: "洗濯機",
        category: :furniture,
        status: :confirmed,
        amount: 32_000
      )

      expect(cost_item).to be_valid
    end

    it "候補にない費用名でも保存できる" do
      cost_item = described_class.new(
        cost_list: cost_list,
        name: "カーテン",
        category: :furniture,
        status: :confirmed,
        amount: 5_000
      )

      expect(cost_item.save).to be true
    end

    it "費用名が空の場合は無効になる" do
      cost_item = described_class.new(
        cost_list: cost_list,
        name: "",
        category: :furniture,
        status: :confirmed,
        amount: 5_000
      )

      expect(cost_item).to be_invalid
      expect(cost_item.errors[:name]).to include("を入力してください")
    end

    it "費用リストが設定されていない場合は無効になる" do
      cost_item = described_class.new(
        cost_list: nil,
        name: "洗濯機",
        category: :furniture,
        status: :confirmed,
        amount: 5_000
      )

      expect(cost_item).to be_invalid
    end
  end

  describe "関連付け" do
    it "費用リストに属する" do
      association = described_class.reflect_on_association(:cost_list)

      expect(association.macro).to eq(:belongs_to)
    end
  end

  describe ".name_options_for" do
    it "賃貸費用の候補を返す" do
      expect(described_class.name_options_for(:rent)).to include("家賃")
    end

    it "引っ越し業者費用の候補を返す" do
      expect(described_class.name_options_for("moving")).to include(
        "引っ越し業者費用"
      )
    end

    it "存在しないカテゴリの場合は空配列を返す" do
      expect(described_class.name_options_for("unknown")).to eq([])
    end
  end

  describe "#reference_estimate_amount" do
    it "引っ越し業者費用の概算金額を返す" do
      cost_item = described_class.new(category: :moving)

      expect(cost_item.reference_estimate_amount).to eq(50_000)
    end

    it "賃貸費用に概算金額がない場合はnilを返す" do
      cost_item = described_class.new(category: :rent)

      expect(cost_item.reference_estimate_amount).to be_nil
    end

    it "費用名ごとの概算金額を優先して返す" do
      cost_item = described_class.new(
        name: "洗濯機",
        category: :furniture
      )

      expect(cost_item.reference_estimate_amount).to eq(32_000)
    end
  end

  describe "#reference_estimate" do
    it "カテゴリに対応した参考説明を返す" do
      cost_item = described_class.new(category: :moving)

      expect(cost_item.reference_estimate).to eq(
        "単身・距離・時期・荷物量によって大きく変動します。"
      )
    end
  end

  describe "category enum" do
    it "カテゴリが定義されている" do
      expect(described_class.categories).to eq(
        "rent" => 0,
        "moving" => 1,
        "furniture" => 2,
        "other" => 3
      )
    end
  end

  describe "status enum" do
    it "ステータスが定義されている" do
      expect(described_class.statuses).to eq(
        "unchecked" => 0,
        "estimated" => 1,
        "confirmed" => 2
      )
    end
  end

  describe "PREFECTURES" do
    it "47都道府県が重複なく定義されている" do
      expect(described_class::PREFECTURES.size).to eq(47)
      expect(described_class::PREFECTURES.uniq.size).to eq(47)
    end
  end
end
