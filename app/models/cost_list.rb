class CostList < ApplicationRecord
  belongs_to :user

  has_many :cost_items, dependent: :destroy

  accepts_nested_attributes_for :cost_items
end
