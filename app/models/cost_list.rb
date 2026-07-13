class CostList < ApplicationRecord
  belongs_to :user

  has_many :cost_items, dependent: :destroy

  validates :title, presence: true, length: { maximum: 50 }

  accepts_nested_attributes_for :cost_items,
                                allow_destroy: true,
                                reject_if: :blank_cost_item?

  private

  def blank_cost_item?(attributes)
    ActiveModel::Type::Boolean.new.cast(attributes["_destroy"]) == false &&
      attributes["name"].blank? &&
      attributes["amount"].blank?
  end
end
