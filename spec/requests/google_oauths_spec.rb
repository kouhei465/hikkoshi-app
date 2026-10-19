require "rails_helper"
require "webmock/rspec"

RSpec.describe "Google OAuth", type: :request do
  GOOGLE_TOKEN_URL = "https://accounts.google.com/o/oauth2/token"
  GOOGLE_USER_INFO_URL = "https://www.googleapis.com/oauth2/v1/userinfo"
  CALLBACK_URL = "http://www.example.com/oauth/google/callback"

  around do |example|
    config = Sorcery::Controller::Config.google
    original_values = {
      key: config.key,
      secret: config.secret,
      callback_url: config.callback_url,
      state: config.state
    }

    config.key = SecureRandom.hex(16)
    config.secret = SecureRandom.hex(32)
    config.callback_url = CALLBACK_URL
    config.state = nil

    example.run
  ensure
    config.key = original_values[:key]
    config.secret = original_values[:secret]
    config.callback_url = original_values[:callback_url]
    config.state = original_values[:state]
  end

  def start_google_oauth
    post google_oauth_path
    Rack::Utils.parse_nested_query(URI.parse(response.location).query)
  end

  def stub_google_oauth(user_info:, token_status: 200)
    access_token = SecureRandom.hex(24)
    token_request = stub_request(:post, GOOGLE_TOKEN_URL).to_return(
      status: token_status,
      body: token_status == 200 ? { access_token:, token_type: "Bearer", expires_in: 3600 }.to_json : "",
      headers: { "Content-Type" => "application/json" }
    )
    user_info_request = stub_request(:get, GOOGLE_USER_INFO_URL).to_return(
      status: 200,
      body: user_info.to_json,
      headers: { "Content-Type" => "application/json" }
    )

    [ token_request, user_info_request ]
  end

  def google_user_info(uid: SecureRandom.uuid, email: "Google.User@Example.COM", name: "Googleユーザー")
    {
      "id" => uid,
      "email" => email,
      "name" => name,
      "verified_email" => true
    }
  end

  def perform_google_callback(user_info:, state: nil, code: SecureRandom.hex(12), token_status: 200)
    state ||= start_google_oauth.fetch("state")
    requests = stub_google_oauth(user_info:, token_status:)
    get google_oauth_callback_path, params: { state:, code: }
    requests
  end

  describe "POST /oauth/google" do
    it "client_id、redirect_uri、scope、stateを付けてGoogleへリダイレクトする" do
      query = start_google_oauth

      expect(response).to redirect_to(a_string_starting_with("https://accounts.google.com/o/oauth2/auth"))
      expect(query["client_id"]).to eq(Sorcery::Controller::Config.google.key)
      expect(query["redirect_uri"]).to eq(CALLBACK_URL)
      expect(query["scope"]).to include("https://www.googleapis.com/auth/userinfo.email")
      expect(query["scope"]).to include("https://www.googleapis.com/auth/userinfo.profile")
      expect(query["state"]).to be_present
      expect(request.session[:google_oauth_state]).to eq(query["state"])
    end

    it "ログイン画面と新規登録画面にPOSTのGoogleログインボタンを表示する" do
      [ login_path, new_user_path ].each do |path|
        get path
        document = Nokogiri::HTML(response.body)
        form = document.at_css("form[action='#{google_oauth_path}'][method='post']")

        expect(form).to be_present
        expect(form.text).to include("Googleでログイン")
      end
    end

    it "設定が不足している場合はGoogleへ接続せずログイン画面へ戻す" do
      config = Sorcery::Controller::Config.google
      config.key = nil

      post google_oauth_path

      expect(response).to redirect_to(login_path)
      expect(flash[:alert]).to eq("Googleログインは現在利用できません")
    end

    it "ログイン済みユーザーはGoogleへ接続せずマイページへ戻す" do
      user = User.create!(
        name: "ログイン済みユーザー",
        email: "already-logged-in@example.com",
        password: "password",
        password_confirmation: "password"
      )
      post login_path, params: { email: user.email, password: "password" }

      post google_oauth_path

      expect(response).to redirect_to(mypage_path)
      expect(flash[:alert]).to eq("すでにログインしています")
    end
  end

  describe "GET /oauth/google/callback" do
    it "stateが一致しない場合はトークン交換を実行しない" do
      start_google_oauth
      token_request = stub_request(:post, GOOGLE_TOKEN_URL)

      get google_oauth_callback_path, params: { state: "invalid-state", code: SecureRandom.hex(12) }

      expect(response).to redirect_to(login_path)
      expect(flash[:alert]).to include("Googleログインを確認できませんでした")
      expect(token_request).not_to have_been_requested
    end

    it "stateが欠落している場合はトークン交換を実行しない" do
      start_google_oauth
      token_request = stub_request(:post, GOOGLE_TOKEN_URL)

      get google_oauth_callback_path, params: { code: SecureRandom.hex(12) }

      expect(response).to redirect_to(login_path)
      expect(token_request).not_to have_been_requested
    end

    it "一度使用したstateは再利用できない" do
      state = start_google_oauth.fetch("state")

      get google_oauth_callback_path, params: { state:, error: "access_denied" }
      expect(flash[:alert]).to eq("Googleログインをキャンセルしました")

      get google_oauth_callback_path, params: { state:, code: SecureRandom.hex(12) }

      expect(response).to redirect_to(login_path)
      expect(flash[:alert]).to include("Googleログインを確認できませんでした")
    end

    it "Google認証をキャンセルした場合は安全な日本語メッセージを表示する" do
      state = start_google_oauth.fetch("state")

      get google_oauth_callback_path, params: { state:, error: "access_denied" }

      expect(response).to redirect_to(login_path)
      follow_redirect!
      expect(response.body).to include("Googleログインをキャンセルしました")
    end

    it "初回ログインではGoogle情報からユーザーとAuthenticationを作成してログインする" do
      uid = SecureRandom.uuid
      user_info = google_user_info(uid:, email: "  Google.User@Example.COM  ", name: " Googleユーザー ")

      expect do
        perform_google_callback(user_info:)
      end.to change(User, :count).by(1).and change(Authentication, :count).by(1)

      user = User.find_by!(email: "google.user@example.com")
      expect(user.name).to eq("Googleユーザー")
      expect(user.crypted_password).to be_nil
      expect(user.authentications.find_by(provider: "google")&.uid).to eq(uid)
      expect(response).to redirect_to(mypage_path)

      get mypage_path
      expect(response).to have_http_status(:ok)
    end

    it "既存GoogleユーザーではUserを増やさずログインする" do
      uid = SecureRandom.uuid
      user = User.new(name: "既存Googleユーザー", email: "existing-google@example.com")
      user.authentications.build(provider: "google", uid:)
      user.save!

      expect do
        perform_google_callback(user_info: google_user_info(uid:, email: user.email, name: user.name))
      end.not_to change(User, :count)

      expect(response).to redirect_to(mypage_path)
      get mypage_path
      expect(response).to have_http_status(:ok)
    end

    it "既存Googleユーザーのログインでセッションを再生成し、保存待ちの内容を結果画面へ引き継ぐ" do
      uid = SecureRandom.uuid
      user = User.new(name: "入力を引き継ぐユーザー", email: "pending-google@example.com")
      user.authentications.build(provider: "google", uid:)
      user.save!
      post cost_lists_path, params: {
        cost_list: {
          budget: 300_000,
          cost_items_attributes: {
            "0" => { name: "家賃", category: "rent", amount: 70_000, status: "estimated" }
          }
        }
      }
      post save_session_cost_lists_path, params: {
        cost_list: { title: "保存待ちのリスト", memo: "ログイン前の判断メモ" }
      }
      previous_session_id = request.session.id.to_s
      previous_token = request.session[:cost_list_draft_token]

      expect do
        perform_google_callback(user_info: google_user_info(uid:, email: user.email))
      end.not_to change(CostList, :count)

      expect(request.session.id.to_s).not_to eq(previous_session_id)
      expect(request.session[:cost_list_draft_token]).not_to eq(previous_token)
      expect(CostListDraft.find_for(token: previous_token, user:)).to be_nil
      expect(response).to redirect_to(result_cost_lists_path)
      follow_redirect!
      expect(response.body).to include("家賃", "70,000円", "保存待ちのリスト", "ログイン前の判断メモ")

      expect do
        post save_session_cost_lists_path, params: {
          cost_list: { title: "保存待ちのリスト", memo: "ログイン前の判断メモ" }
        }
      end.to change(user.cost_lists, :count).by(1)
      saved = user.cost_lists.last
      expect(saved.budget).to eq(300_000)
      expect(saved.memo).to eq("ログイン前の判断メモ")
      expect(saved.cost_items.first.attributes.slice("name", "amount", "category", "status")).to eq(
        "name" => "家賃", "amount" => 70_000, "category" => "rent", "status" => "estimated"
      )
      get result_cost_lists_path
      expect(response).to redirect_to(new_cost_list_path)
    end

    it "4KBを超える費用項目と長文メモを既存Googleログイン後も計算・保存できる" do
      uid = SecureRandom.uuid
      user = User.new(name: "大容量入力ユーザー", email: "large-google@example.com")
      user.authentications.build(provider: "google", uid:)
      user.save!
      items = 40.times.to_h do |index|
        [ index.to_s, { name: "費用#{index}：#{'確認事項' * 15}", category: "other", amount: 1_000, status: "unchecked" } ]
      end
      memo = "引っ越し前に確認する判断メモ。" * 500
      expect(items.to_json.bytesize).to be > 8_000
      expect(memo.bytesize).to be > 8_000

      post cost_lists_path, params: { cost_list: { budget: 100_000, cost_items_attributes: items } }
      expect(response).to redirect_to(result_cost_lists_path)
      expect(response.headers["Set-Cookie"].to_s.bytesize).to be < 4_096
      get result_cost_lists_path
      expect(response.body).to include("40,000円")
      post save_session_cost_lists_path, params: { cost_list: { title: "大容量のリスト", memo: } }
      expect(response.headers["Set-Cookie"].to_s.bytesize).to be < 4_096

      perform_google_callback(user_info: google_user_info(uid:, email: user.email))

      expect(response).to redirect_to(result_cost_lists_path)
      follow_redirect!
      expect(response.body).to include(memo)
      expect(request.session[:cost_list_params]).to be_nil
      expect(response.headers["Set-Cookie"].to_s.bytesize).to be < 4_096
      post save_session_cost_lists_path, params: { cost_list: { title: "大容量のリスト", memo: } }
      expect(response).to redirect_to(mypage_path)
      saved = user.cost_lists.last
      expect(saved.memo).to eq(memo)
      expect(saved.cost_items.size).to eq(40)
      expect(saved.cost_items.sum(:amount)).to eq(40_000)
    end

    it "Google認証失敗後も保存待ちの入力を保持する" do
      post cost_lists_path, params: {
        cost_list: {
          budget: 300_000,
          cost_items_attributes: {
            "0" => { name: "家賃", category: "rent", amount: 70_000, status: "estimated" }
          }
        }
      }
      post save_session_cost_lists_path, params: { cost_list: { title: "認証前の入力", memo: "判断メモ" } }

      perform_google_callback(user_info: google_user_info, token_status: 503)

      expect(response).to redirect_to(login_path)
      get result_cost_lists_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("認証前の入力", "判断メモ", "70,000円")
    end

    it "Google新規登録時に保存できなかった内容を保持し、原因を表示して再保存できる" do
      post cost_lists_path, params: { cost_list: { budget: 300_000 } }
      memo = "登録時の長文メモ。" * 500
      post save_session_cost_lists_path, params: { cost_list: { title: "あ" * 51, memo: } }
      previous_session_id = request.session.id.to_s

      perform_google_callback(user_info: google_user_info(email: "failed-draft-google@example.com"))

      expect(request.session.id.to_s).not_to eq(previous_session_id)
      expect(response).to redirect_to(result_cost_lists_path)
      expect(flash[:alert]).to include("リスト名は50文字以内")
      follow_redirect!
      expect(response.body).to include(memo)
      expect do
        post save_session_cost_lists_path, params: { cost_list: { title: "修正した名前" } }
      end.to change(CostListDraft, :count).by(-1)
      user = User.find_by!(email: "failed-draft-google@example.com")
      expect(user.cost_lists.last.memo).to eq(memo)
    end

    it "同一メールアドレスの通常ユーザーには自動連携しない" do
      normal_user = User.create!(
        name: "通常ユーザー",
        email: "registered@example.com",
        password: "password",
        password_confirmation: "password"
      )

      expect do
        perform_google_callback(
          user_info: google_user_info(email: normal_user.email, name: "別のGoogleユーザー")
        )
      end.not_to change(User, :count)

      expect(Authentication.count).to eq(0)
      expect(response).to redirect_to(login_path)
      expect(flash[:alert]).to include("メールアドレスとパスワードでログインしてください")

      get mypage_path
      expect(response).to redirect_to(login_path)
    end

    it "大文字小文字だけが異なる通常ユーザーにも自動連携しない" do
      User.create!(
        name: "通常ユーザー",
        email: "Registered@Example.COM",
        password: "password",
        password_confirmation: "password"
      )

      expect do
        perform_google_callback(user_info: google_user_info(email: "registered@example.com"))
      end.not_to change(User, :count)

      expect(Authentication.count).to eq(0)
      expect(response).to redirect_to(login_path)
    end

    it "Google API障害時はUserもAuthenticationも作成しない" do
      expect do
        perform_google_callback(user_info: google_user_info, token_status: 503)
      end.not_to change(User, :count)

      expect(Authentication.count).to eq(0)
      expect(response).to redirect_to(login_path)
      expect(flash[:alert]).to include("Googleログインに失敗しました")
    end

    it "DB競合時は生の例外を表示せず安全に失敗する" do
      allow(User).to receive(:create_and_validate_from_provider).and_raise(ActiveRecord::RecordNotUnique)

      expect do
        perform_google_callback(user_info: google_user_info)
      end.not_to change(User, :count)

      expect(Authentication.count).to eq(0)
      expect(response).to redirect_to(login_path)
      expect(flash[:alert]).to include("Googleログインを完了できませんでした")
      expect(response.body).not_to include("ActiveRecord")
    end

    it "必要情報が不足している場合は代替値を作らず登録しない" do
      incomplete_info = google_user_info.merge("name" => "")

      expect do
        perform_google_callback(user_info: incomplete_info)
      end.not_to change(User, :count)

      expect(Authentication.count).to eq(0)
      expect(response).to redirect_to(login_path)
    end

    it "verified_emailがfalseの場合は登録しない" do
      unverified_info = google_user_info.merge("verified_email" => false)

      expect do
        perform_google_callback(user_info: unverified_info)
      end.not_to change(User, :count)

      expect(Authentication.count).to eq(0)
      expect(response).to redirect_to(login_path)
    end

    it "ゲスト入力済みの費用データを初回登録後に保存する" do
      post cost_lists_path, params: {
        cost_list: {
          budget: 300_000,
          cost_items_attributes: {
            "0" => {
              name: "家賃",
              category: "rent",
              amount: 70_000,
              status: "estimated"
            }
          }
        }
      }
      post save_session_cost_lists_path, params: {
        cost_list: { title: "Google登録時の費用", memo: "ゲスト入力" }
      }

      perform_google_callback(user_info: google_user_info(email: "google-guest@example.com"))

      user = User.find_by!(email: "google-guest@example.com")
      cost_list = user.cost_lists.find_by!(title: "Google登録時の費用")
      expect(cost_list.memo).to eq("ゲスト入力")
      expect(cost_list.cost_items.first.name).to eq("家賃")
      expect(response).to redirect_to(mypage_path)
    end

    it "Google専用ユーザーには編集リンクを表示せず、直接アクセスによる変更も拒否する" do
      perform_google_callback(user_info: google_user_info(email: "google-restricted@example.com"))
      user = User.find_by!(email: "google-restricted@example.com")

      get mypage_path
      expect(response.body).not_to include("ユーザー情報を編集する")

      get edit_mypage_path
      expect(response).to redirect_to(mypage_path)
      expect(flash[:alert]).to include("Googleログイン専用ユーザー")

      patch mypage_path, params: {
        user: { email: "changed@example.com", current_password: "irrelevant" }
      }
      expect(response).to redirect_to(mypage_path)
      expect(user.reload.email).to eq("google-restricted@example.com")
    end
  end
end
