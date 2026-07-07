require "rails_helper"

RSpec.describe "ログイン", type: :request do
  describe "GET /login" do
    it "正常にアクセスできること" do
      get login_path

      expect(response).to have_http_status(:ok)
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
