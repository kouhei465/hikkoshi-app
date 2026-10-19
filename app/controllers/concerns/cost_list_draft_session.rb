module CostListDraftSession
  private

  def current_cost_list_draft
    return @current_cost_list_draft if defined?(@current_cost_list_draft)

    @current_cost_list_draft = CostListDraft.find_for(
      token: session[:cost_list_draft_token], user: current_user
    )
    session.delete(:cost_list_draft_token) unless @current_cost_list_draft
    @current_cost_list_draft
  end

  def store_cost_list_draft(attributes)
    if current_cost_list_draft
      current_cost_list_draft.refresh!(attributes:)
    else
      @current_cost_list_draft, token = CostListDraft.create_for(attributes:, user: current_user)
      session[:cost_list_draft_token] = token
    end
  end

  # Sorceryによるセッション再生成後は、一時データ用の識別子だけを引き継ぐ。
  # 識別子も交換し、ログイン前のCookieからは参照できないようにする。
  def retain_cost_list_draft_after_login(draft)
    return unless draft

    session[:cost_list_draft_token] = draft.claim!(user: current_user)
    @current_cost_list_draft = draft
  end

  def discard_cost_list_draft
    current_cost_list_draft&.destroy!
    session.delete(:cost_list_draft_token)
    @current_cost_list_draft = nil
  end
end
