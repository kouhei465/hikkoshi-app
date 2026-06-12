class CostItem < ApplicationRecord
  NAME_OPTIONS_BY_CATEGORY = {
    "rent" => %w[家賃 敷金 礼金 仲介手数料 前家賃 火災保険料 その他賃貸費用],
    "moving" => %w[引っ越し業者費用 その他引っ越し費用],
    "furniture" => %w[洗濯機 冷蔵庫 テレビ 電子レンジ 炊飯器 電気ケトル・電気ポット 掃除機 その他家具家電費用],
    "other" => %w[交通費 手続き費用 雑費 その他費用]
  }.freeze

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
