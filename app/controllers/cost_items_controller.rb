class CostItemsController < ApplicationController
  def update_status
    @cost_list = current_user.cost_lists.find(params[:cost_list_id])
    @cost_item = @cost_list.cost_items.find(params[:id])

    if @cost_item.update(status_params)
      redirect_to cost_list_path(@cost_list), notice: "ステータスを更新しました"
    else
      redirect_to cost_list_path(@cost_list), alert: "ステータスの更新に失敗しました"
    end
  end

  private

  def status_params
    params.require(:cost_item).permit(:status)
  end
end
