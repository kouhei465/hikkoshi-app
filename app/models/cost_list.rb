class CostList < ApplicationRecord
  belongs_to :user

  has_many :cost_items, dependent: :destroy
end
