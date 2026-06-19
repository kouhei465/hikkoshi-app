class CostItem < ApplicationRecord
  NAME_OPTIONS_BY_CATEGORY = {
    "rent" => %w[家賃 敷金 礼金 仲介手数料 前家賃 火災保険料 その他賃貸費用],
    "moving" => %w[引っ越し業者費用 その他引っ越し費用],
    "furniture" => %w[洗濯機 冷蔵庫 テレビ 電子レンジ 炊飯器 電気ケトル・電気ポット 掃除機 その他家具家電費用],
    "other" => %w[交通費 手続き費用 雑費 その他費用]
  }.freeze

  PREFECTURES = %w[
    北海道 青森県 岩手県 宮城県 秋田県 山形県 福島県
    茨城県 栃木県 群馬県 埼玉県 千葉県 東京都 神奈川県
    新潟県 富山県 石川県 福井県 山梨県 長野県
    岐阜県 静岡県 愛知県 三重県
    滋賀県 京都府 大阪府 兵庫県 奈良県 和歌山県
    鳥取県 島根県 岡山県 広島県 山口県
    徳島県 香川県 愛媛県 高知県
    福岡県 佐賀県 長崎県 熊本県 大分県 宮崎県 鹿児島県 沖縄県
  ].freeze

  REFERENCE_ESTIMATES = {
    "rent" => "家賃を入力すると、敷金・礼金などの目安を考えやすくなります。",
    "moving" => "単身・距離・時期・荷物量によって大きく変動します。",
    "furniture" => "購入する家具家電の数などによって変動します。",
    "other" => "手続き費用・交通費・生活用品などの雑費として変動します。"
  }.freeze

  REFERENCE_ESTIMATE_AMOUNTS = {
    "moving" => 50_000,
    "furniture" => 100_000,
    "other" => 30_000
  }.freeze

  REFERENCE_ESTIMATE_AMOUNTS_BY_NAME = {
    "洗濯機" => 32_000,
    "冷蔵庫" => 28_000,
    "テレビ" => 30_000,
    "電子レンジ" => 10_000,
    "炊飯器" => 10_000,
    "電気ケトル・電気ポット" => 4_000,
    "掃除機" => 8_000,
    "その他家具家電費用" => 10_000
  }.freeze

  belongs_to :cost_list

  validates :name, presence: true

  enum :category, {
    rent: 0,
    moving: 1,
    furniture: 2,
    other: 3
  }

  enum :status, {
    unchecked: 0,
    estimated: 1,
    confirmed: 2
  }

  def reference_estimate
    REFERENCE_ESTIMATES[category]
  end

  def reference_estimate_amount
    REFERENCE_ESTIMATE_AMOUNTS_BY_NAME[name] || REFERENCE_ESTIMATE_AMOUNTS[category]
  end

  def self.name_options_for(category)
    NAME_OPTIONS_BY_CATEGORY[category.to_s] || []
  end
end
