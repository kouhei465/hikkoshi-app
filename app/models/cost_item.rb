class CostItem < ApplicationRecord
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
end
