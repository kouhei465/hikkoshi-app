class CostListsController < ApplicationController
  def new
    @cost_list = CostList.new
    @cost_list.cost_items.build(name: "賃貸費用", category: :rent)
    @cost_list.cost_items.build(name: "引っ越し業者費用", category: :moving)
    @cost_list.cost_items.build(name: "家具家電費用", category: :furniture)
    @cost_list.cost_items.build(name: "その他費用", category: :other)
  end

  def create
    session[:cost_list_params] = cost_list_params.to_h

    redirect_to result_cost_lists_path
  end

  def result
    return redirect_to new_cost_list_path if session[:cost_list_params].blank?

    @cost_list = CostList.new(session[:cost_list_params])
    calculate_result
  end

  def show
    @cost_list = current_user.cost_lists.find(params[:id])
    calculate_result
  end

  def save_session
    return redirect_to mypage_path, alert: "保存する費用データがありません" if session[:cost_list_params].blank?
    return redirect_to login_path, alert: "保存するにはログインしてください" unless logged_in?

    @cost_list = current_user.cost_lists.build(session[:cost_list_params])
    @cost_list.title = "引っ越し費用リスト"

    if @cost_list.save
      session.delete(:cost_list_params)
      redirect_to mypage_path, notice: "費用リストを保存しました"
    else
      redirect_to result_cost_lists_path, alert: "保存に失敗しました"
    end
  end

  private

  def cost_list_params
    params.require(:cost_list).permit(
      :budget,
      cost_items_attributes: %i[name category amount status]
    )
  end

  def calculate_result
    @total_amount = @cost_list.cost_items.sum { |item| item.amount.to_i }
    @budget_amount = @cost_list.budget.to_i
    @difference = @budget_amount - @total_amount
  end
end
