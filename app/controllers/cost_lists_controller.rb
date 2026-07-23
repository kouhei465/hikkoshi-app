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

  def destroy
    @cost_list = current_user.cost_lists.find(params[:id])
    @cost_list.destroy!

    redirect_to mypage_path, notice: "費用リストを削除しました"
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

  def update_title
    @cost_list = current_user.cost_lists.find(params[:id])

    if @cost_list.update(title_params)
      redirect_to mypage_path, notice: "リスト名を変更しました"
    else
      redirect_to mypage_path, alert: "リスト名を変更できませんでした"
    end
  end

  def save_session
    return redirect_to mypage_path, alert: "保存する費用データがありません" if session[:cost_list_params].blank?

    submitted_title = params.dig(:cost_list, :title).to_s.strip
    memo = params.dig(:cost_list, :memo)

    session[:cost_list_params]["title"] = submitted_title.presence || "引っ越し費用リスト"
    session[:cost_list_params]["memo"] = memo if memo

    return redirect_to login_path, alert: "保存するにはログインしてください" unless logged_in?

    @cost_list = current_user.cost_lists.build(session[:cost_list_params])

    if @cost_list.save
      session.delete(:cost_list_params)
      redirect_to mypage_path, notice: "費用リストを保存しました"
    else
      redirect_to result_cost_lists_path, alert: "保存に失敗しました"
    end
  end

  def compare
    return redirect_to login_path, alert: "ログインしてください" unless logged_in?

    ids = Array(params[:cost_list_ids]).reject(&:blank?).uniq

    if ids.size != 2
      redirect_to mypage_path, alert: "比較する費用リストを2件選択してください"
      return
    end

    cost_lists = current_user.cost_lists
                             .includes(:cost_items)
                             .where(id: ids)
                             .to_a

    if cost_lists.size != 2
      redirect_to mypage_path, alert: "比較対象の費用リストを確認できませんでした"
      return
    end

    @cost_lists = ids.filter_map do |id|
      cost_lists.find { |cost_list| cost_list.id == id.to_i }
    end
    @comparison_data = @cost_lists.map { |cost_list| build_cost_summary(cost_list) }
  end

  private

  def cost_list_params
    params.require(:cost_list).permit(
      :title,
      :budget,
      :memo,
      cost_items_attributes: %i[id name category amount status _destroy]
    )
  end

  def memo_params
    params.require(:cost_list).permit(:memo)
  end

  def title_params
    params.require(:cost_list).permit(:title)
  end

  def calculate_result
    summary = build_cost_summary(@cost_list)

    @total_amount = summary[:total_amount]
    @budget_amount = summary[:budget_amount]
    @difference = summary[:difference]
    @category_totals = summary[:category_totals]
    @largest_category = summary[:largest_category]
  end

  def build_cost_summary(cost_list)
    cost_items = cost_list.cost_items.reject(&:marked_for_destruction?)
    total_amount = cost_items.sum { |item| item.amount.to_i }
    budget_amount = cost_list.budget.to_i
    category_totals = CostItem.categories.keys.to_h do |category|
      category_total = cost_items
                       .select { |item| item.category == category }
                       .sum { |item| item.amount.to_i }

      [ category, category_total ]
    end
    largest_category = category_totals
                       .select { |_category, amount| amount.positive? }
                       .max_by { |_category, amount| amount }

    {
      cost_list: cost_list,
      total_amount: total_amount,
      budget_amount: budget_amount,
      difference: budget_amount - total_amount,
      category_totals: category_totals,
      largest_category: largest_category
    }
  end

  def build_initial_cost_items
    CostItem.categories.keys.each do |category|
      @cost_list.cost_items.build(
        category: category,
        status: :unchecked
      )
    end
  end
end
