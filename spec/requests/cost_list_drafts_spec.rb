require "rails_helper"

RSpec.describe "費用入力の一時保存", type: :request do
  let(:user) do
    User.create!(name: "一時保存ユーザー", email: "draft@example.com",
                 password: "password", password_confirmation: "password")
  end
  let(:attributes) do
    {
      budget: 200_000,
      cost_items_attributes: {
        "0" => { name: "確認前の費用", amount: 50_000, category: "moving", status: "unchecked" }
      }
    }
  end

  def create_draft
    post cost_lists_path, params: { cost_list: attributes }
    expect(response).to redirect_to(result_cost_lists_path)
    CostListDraft.last
  end

  it "Cookieには識別子のみを保存し、再計算では同じ一時データを更新する" do
    draft = create_draft

    expect(request.session[:cost_list_draft_token]).to be_present
    expect(request.session[:cost_list_params]).to be_nil
    expect(draft.data["budget"]).to eq("200000")
    expect(response.headers["Set-Cookie"].to_s.bytesize).to be < 4_096

    expect do
      post cost_lists_path, params: { cost_list: attributes.merge(budget: 300_000) }
    end.not_to change(CostListDraft, :count)
    expect(draft.reload.data["budget"]).to eq("300000")
  end

  it "別のブラウザから識別子をパラメータに指定しても参照・更新できない" do
    draft = create_draft
    token = request.session[:cost_list_draft_token]
    other_browser = ActionDispatch::Integration::Session.new(Rails.application)

    other_browser.get result_cost_lists_path, params: { cost_list_draft_token: token, id: draft.id }
    expect(other_browser.response.location).to eq("http://www.example.com#{new_cost_list_path}")
    other_browser.post save_session_cost_lists_path,
                       params: { cost_list_draft_token: token, id: draft.id, cost_list: { memo: "他人の変更" } }
    expect(other_browser.response.location).to eq("http://www.example.com#{mypage_path}")
    expect(draft.reload.data).not_to have_key("memo")

    get result_cost_lists_path
    expect(response.body).to include("確認前の費用")
  end

  it "期限切れの一時データは結果表示にも保存にも使用しない" do
    draft = create_draft
    draft.update!(expires_at: 1.second.ago)

    get result_cost_lists_path
    expect(response).to redirect_to(new_cost_list_path)
    expect(request.session[:cost_list_draft_token]).to be_nil
    post save_session_cost_lists_path, params: { cost_list: { title: "期限切れ" } }
    expect(response).to redirect_to(mypage_path)
    expect(CostList.count).to eq(0)
  end

  it "メールログインでもセッションを再生成し、保存待ちの入力を結果画面へ引き継ぐ" do
    draft = create_draft
    post save_session_cost_lists_path, params: { cost_list: { title: "保存待ち", memo: "確認メモ" } }
    previous_session_id = request.session.id.to_s
    previous_token = request.session[:cost_list_draft_token]

    post login_path, params: { email: user.email, password: "password" }

    expect(response).to redirect_to(result_cost_lists_path)
    expect(request.session.id.to_s).not_to eq(previous_session_id)
    expect(request.session[:cost_list_draft_token]).not_to eq(previous_token)
    expect(CostListDraft.find_for(token: previous_token, user:)).to be_nil
    expect(draft.reload.user).to eq(user)
    follow_redirect!
    expect(response.body).to include("保存待ち", "確認メモ", "50,000円")

    expect do
      post save_session_cost_lists_path
    end.to change(user.cost_lists, :count).by(1).and change(CostListDraft, :count).by(-1)
    expect(user.cost_lists.last.memo).to eq("確認メモ")
  end

  it "ログイン失敗時も一時データを保持する" do
    draft = create_draft
    post login_path, params: { email: user.email, password: "incorrect" }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(draft.reload).to be_present
    get result_cost_lists_path
    expect(response.body).to include("確認前の費用")
  end

  it "保存失敗時は長文メモをサーバーに保持し、修正後の保存成功時に削除する" do
    post login_path, params: { email: user.email, password: "password" }
    draft = create_draft
    memo = "長文の確認事項。" * 1_000
    post save_session_cost_lists_path, params: { cost_list: { title: "あ" * 51, memo: } }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("リスト名は50文字以内", memo)
    expect(draft.reload.data["memo"]).to eq(memo)
    expect(response.headers["Set-Cookie"].to_s.bytesize).to be < 4_096
    get result_cost_lists_path
    expect(response.body).to include(memo)

    expect do
      post save_session_cost_lists_path, params: { cost_list: { title: "修正済み" } }
    end.to change(CostListDraft, :count).by(-1)
    expect(user.cost_lists.last.memo).to eq(memo)
    expect(request.session[:cost_list_draft_token]).to be_nil
  end

  it "メール登録時の保存失敗でも入力を保持し、原因を表示して再保存できる" do
    draft = create_draft
    post save_session_cost_lists_path, params: { cost_list: { title: "あ" * 51, memo: "登録時のメモ" } }

    post users_path, params: {
      user: { name: "新規ユーザー", email: "draft-signup@example.com",
              password: "password", password_confirmation: "password" }
    }

    expect(response).to redirect_to(result_cost_lists_path)
    expect(flash[:alert]).to include("リスト名は50文字以内")
    expect(draft.reload.user.email).to eq("draft-signup@example.com")
    follow_redirect!
    expect(response.body).to include("登録時のメモ")
    expect do
      post save_session_cost_lists_path, params: { cost_list: { title: "登録後に修正" } }
    end.to change(CostListDraft, :count).by(-1)
    expect(CostList.last.memo).to eq("登録時のメモ")
  end

  it "ログアウト時に利用中の一時データを削除する" do
    post login_path, params: { email: user.email, password: "password" }
    create_draft
    expect do
      delete logout_path
    end.to change(CostListDraft, :count).by(-1)
    get result_cost_lists_path
    expect(response).to redirect_to(new_cost_list_path)
  end
end
