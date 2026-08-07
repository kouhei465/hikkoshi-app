require "rails_helper"

RSpec.describe "ログイン", type: :request do
  describe "GET /login" do
    it "正常にアクセスできること" do
      get login_path

      expect(response).to have_http_status(:ok)
    end

    it "ログイン中はマイページにリダイレクトする" do
      user = User.create!(
        name: "ログイン済みユーザー",
        email: "login-page-guard@example.com",
        password: "password",
        password_confirmation: "password"
      )
      post login_path, params: { email: user.email, password: "password" }

      get login_path

      expect(response).to redirect_to(mypage_path)
      expect(flash[:alert]).to eq("すでにログインしています")
    end
  end

  describe "POST /login" do
    context "ログイン情報が正しい場合" do
      it "ログインが成功すること" do
        user = User.create!(
          name: "ログインユーザー",
          email: "login@example.com",
          password: "password",
          password_confirmation: "password"
        )

        post login_path, params: {
          email: user.email,
          password: "password"
        }

        expect(response).to redirect_to(mypage_path)

        get mypage_path

        expect(response).to have_http_status(:ok)
      end

      it "大文字混在のメールアドレスでもログインできること" do
        User.create!(
          name: "大文字ログインユーザー",
          email: "uppercase-login@example.com",
          password: "password",
          password_confirmation: "password"
        )

        post login_path, params: {
          email: "Uppercase-Login@Example.COM",
          password: "password"
        }

        expect(response).to redirect_to(mypage_path)

        get mypage_path
        expect(response).to have_http_status(:ok)
      end

      it "前後に空白があるメールアドレスでもログインできること" do
        User.create!(
          name: "空白付きログインユーザー",
          email: "trimmed-login@example.com",
          password: "password",
          password_confirmation: "password"
        )

        post login_path, params: {
          email: "  trimmed-login@example.com  ",
          password: "password"
        }

        expect(response).to redirect_to(mypage_path)

        get mypage_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "ログイン情報が間違っている場合" do
      it "ログインに失敗すること" do
        user = User.create!(
          name: "ログイン失敗ユーザー",
          email: "login-failure@example.com",
          password: "password",
          password_confirmation: "password"
        )

        post login_path, params: {
          email: user.email,
          password: "wrong-password"
        }

        expect(response).to have_http_status(:unprocessable_entity)

        get mypage_path

        expect(response).to redirect_to(login_path)
      end
    end

    context "すでにログイン中の場合" do
      it "通常ログインを実行せず現在のユーザーを維持する" do
        current_user = User.create!(
          name: "現在ログイン中のユーザー",
          email: "current-login@example.com",
          password: "password",
          password_confirmation: "password"
        )
        other_user = User.create!(
          name: "切り替わらないユーザー",
          email: "other-login@example.com",
          password: "password",
          password_confirmation: "password"
        )
        current_user.cost_lists.create!(title: "現在のユーザーの費用")
        other_user.cost_lists.create!(title: "他ユーザーの費用")
        post login_path, params: { email: current_user.email, password: "password" }

        post login_path, params: { email: other_user.email, password: "password" }

        expect(response).to redirect_to(mypage_path)
        expect(flash[:alert]).to eq("すでにログインしています")

        get mypage_path
        expect(response.body).to include("現在のユーザーの費用")
        expect(response.body).not_to include("他ユーザーの費用")
      end
    end
  end

  describe "DELETE /logout" do
    it "ログイン中のユーザーがログアウトできること" do
      user = User.create!(
        name: "ログアウトユーザー",
        email: "logout@example.com",
        password: "password",
        password_confirmation: "password"
      )

      post login_path, params: {
        email: user.email,
        password: "password"
      }

      expect(response).to redirect_to(mypage_path)

      delete logout_path

      expect(response).to redirect_to(root_path)

      get mypage_path

      expect(response).to redirect_to(login_path)
    end
  end
end
