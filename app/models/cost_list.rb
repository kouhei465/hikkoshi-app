class CostList < ApplicationRecord
  belongs_to :user, optional: true

  has_many :cost_items, dependent: :destroy

  # 計算だけならゲストでも利用できる。保存時にはユーザーとリスト名を必須にする。
  validates :user, :title, presence: true, unless: -> { validation_context == :calculation }
  validates :title, length: { maximum: 50 }
  validates :budget,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 0
            },
            allow_nil: true

  accepts_nested_attributes_for :cost_items,
                                allow_destroy: true,
                                reject_if: :blank_cost_item?

  private

  def blank_cost_item?(attributes)
    ActiveModel::Type::Boolean.new.cast(attributes["_destroy"]) != true &&
      attributes["name"].blank? &&
      attributes["amount"].blank?
  end
end
