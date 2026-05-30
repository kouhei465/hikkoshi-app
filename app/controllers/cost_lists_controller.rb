class CostListsController < ApplicationController
def new
  @cost_list = CostList.new

  @cost_list.cost_items.build(name: "賃貸費用", category: :rent)
  @cost_list.cost_items.build(name: "引っ越し業者費用", category: :moving)
  @cost_list.cost_items.build(name: "家具家電費用", category: :furniture)
  @cost_list.cost_items.build(name: "その他費用", category: :other)
end

  def create
  end
end
