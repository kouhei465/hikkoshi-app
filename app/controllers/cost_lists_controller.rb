class CostListsController < ApplicationController
  def new
    @cost_list = CostList.new
    build_initial_cost_items
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

  def edit
    @cost_list = current_user.cost_lists.find(params[:id])
  end

  def update
    @cost_list = current_user.cost_lists.find(params[:id])

    if @cost_list.update(cost_list_params)
      redirect_to cost_list_path(@cost_list), notice: "費用内容を更新しました"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def update_memo
    @cost_list = current_user.cost_lists.find(params[:id])

    if @cost_list.update(memo_params)
      redirect_to cost_list_path(@cost_list), notice: "判断メモを更新しました"
    else
      calculate_result
      flash.now[:alert] = "判断メモの更新に失敗しました"
      render :show, status: :unprocessable_entity
    end
  end

  def save_session
    return redirect_to mypage_path, alert: "保存する費用データがありません" if session[:cost_list_params].blank?

    memo = params.dig(:cost_list, :memo)
    session[:cost_list_params]["memo"] = memo if memo

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
      :memo,
      cost_items_attributes: %i[id name category amount status _destroy]
    )
  end

  def memo_params
    params.require(:cost_list).permit(:memo)
  end

  def calculate_result
    @total_amount = @cost_list.cost_items.sum { |item| item.amount.to_i }
    @budget_amount = @cost_list.budget.to_i
    @difference = @budget_amount - @total_amount
  end

  def build_initial_cost_items
    CostItem.categories.keys.each do |category|
      @cost_list.cost_items.build(
        name: CostItem.name_options_for(category).first,
        category: category,
        status: :unchecked
      )
    end
  end
end
