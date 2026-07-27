require "rails_helper"

RSpec.describe "パスワード再設定", type: :request do
  let(:user) do
    User.create!(
      name: "パスワード再設定ユーザー",
      email: "password-reset@example.com",
      password: "password",
      password_confirmation: "password"
    )
  end

  before do
    ActionMailer::Base.deliveries.clear
  end

  describe "GET /password_resets/new" do
    it "メールアドレス入力画面を表示する" do
      get new_password_reset_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("登録したメールアドレスを入力してください")
    end
  end

  describe "ログイン画面" do
    it "パスワード再設定画面へのリンクを表示する" do
      get login_path

      expect(response.body).to include("パスワードを忘れた方はこちら")
      expect(response.body).to include(new_password_reset_path)
    end
  end

  describe "POST /password_resets" do
    context "登録済みのメールアドレスの場合" do
      it "再設定トークンを発行し、HTMLとテキストを含むメールを送信する" do
        expect do
          post password_resets_path, params: { email: user.email }
        end.to change(ActionMailer::Base.deliveries, :count).by(1)

        expect(response).to redirect_to(login_path)

        user.reload
        email = ActionMailer::Base.deliveries.last
        reset_url = edit_password_reset_url(user.reset_password_token)

        expect(user.reset_password_token).to be_present
        expect(user.reset_password_token_expires_at).to be_within(5.seconds).of(2.hours.from_now)
        expect(email.to).to eq([ user.email ])
        expect(email.subject).to eq("パスワード再設定のご案内")
        expect(email.html_part.body.decoded).to include(reset_url)
        expect(email.text_part.body.decoded).to include(reset_url)

        follow_redirect!

        expect(response.body).to include(
          "ご入力のメールアドレスが登録されている場合、パスワード再設定用のメールを送信しました"
        )
      end

      it "5分以内に再送信しても新しいメールを送信しない" do
        post password_resets_path, params: { email: user.email }

        expect do
          post password_resets_path, params: { email: user.email }
        end.not_to change(ActionMailer::Base.deliveries, :count)

        expect(response).to redirect_to(login_path)
      end
    end

    context "未登録のメールアドレスの場合" do
      it "メールを送信せず、登録済みの場合と同じ案内を表示する" do
        expect do
          post password_resets_path, params: { email: "unknown@example.com" }
        end.not_to change(ActionMailer::Base.deliveries, :count)

        expect(response).to redirect_to(login_path)

        follow_redirect!

        expect(response.body).to include(
          "ご入力のメールアドレスが登録されている場合、パスワード再設定用のメールを送信しました"
        )
      end
    end
  end

  describe "GET /password_resets/:id/edit" do
    it "有効なトークンの場合はパスワード再設定画面を表示する" do
      user.generate_reset_password_token!

      get edit_password_reset_path(user.reset_password_token)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("新しいパスワード")
    end

    it "不正なトークンの場合はパスワード再設定を拒否する" do
      get edit_password_reset_path("invalid-token")

      expect(response).to redirect_to(new_password_reset_path)

      follow_redirect!

      expect(response.body).to include("パスワード再設定用のリンクが無効か、有効期限が切れています")
    end

    it "期限切れのトークンの場合はパスワード再設定を拒否する" do
      user.generate_reset_password_token!
      token = user.reset_password_token
      user.update_column(:reset_password_token_expires_at, 1.minute.ago)

      get edit_password_reset_path(token)

      expect(response).to redirect_to(new_password_reset_path)
    end

    it "使用済みのトークンの場合はパスワード再設定を拒否する" do
      user.generate_reset_password_token!
      token = user.reset_password_token
      user.reload
      user.password_confirmation = "new-password"

      expect(user.change_password("new-password")).to be(true)

      get edit_password_reset_path(token)

      expect(response).to redirect_to(new_password_reset_path)
    end
  end

  describe "PATCH /password_resets/:id" do
    it "有効なトークンとパスワードの場合はパスワードを変更する" do
      user.generate_reset_password_token!
      token = user.reset_password_token

      patch password_reset_path(token), params: {
        user: {
          name: "変更されない名前",
          password: "new-password",
          password_confirmation: "new-password"
        }
      }

      expect(response).to redirect_to(login_path)

      user.reload

      expect(user.name).to eq("パスワード再設定ユーザー")
      expect(user.valid_password?("password")).to be(false)
      expect(user.valid_password?("new-password")).to be(true)
      expect(user.reset_password_token).to be_nil
      expect(user.reset_password_token_expires_at).to be_nil

      follow_redirect!

      expect(response.body).to include("パスワードを変更しました。新しいパスワードでログインしてください")
    end

    it "edit表示後に期限切れになったトークンを再検証して拒否する" do
      user.generate_reset_password_token!
      token = user.reset_password_token

      get edit_password_reset_path(token)
      expect(response).to have_http_status(:ok)

      user.update_column(:reset_password_token_expires_at, 1.minute.ago)

      patch password_reset_path(token), params: {
        user: {
          password: "new-password",
          password_confirmation: "new-password"
        }
      }

      expect(response).to redirect_to(new_password_reset_path)
      expect(user.reload.valid_password?("password")).to be(true)
    end

    it "不正なトークンの場合はパスワード変更を拒否する" do
      patch password_reset_path("invalid-token"), params: {
        user: {
          password: "new-password",
          password_confirmation: "new-password"
        }
      }

      expect(response).to redirect_to(new_password_reset_path)
      expect(user.reload.valid_password?("password")).to be(true)
    end

    it "使用済みのトークンの場合は再利用を拒否する" do
      user.generate_reset_password_token!
      token = user.reset_password_token

      patch password_reset_path(token), params: {
        user: {
          password: "new-password",
          password_confirmation: "new-password"
        }
      }

      patch password_reset_path(token), params: {
        user: {
          password: "another-password",
          password_confirmation: "another-password"
        }
      }

      expect(response).to redirect_to(new_password_reset_path)
      expect(user.reload.valid_password?("new-password")).to be(true)
    end

    it "空のパスワードの場合は変更せず、トークンを維持する" do
      user.generate_reset_password_token!
      token = user.reset_password_token

      patch password_reset_path(token), params: {
        user: {
          password: "",
          password_confirmation: ""
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("パスワードは3文字以上で入力してください")
      expect(user.reload.valid_password?("password")).to be(true)
      expect(user.reset_password_token).to eq(token)
    end

    it "パスワードが送信されていない場合は変更せず、トークンを維持する" do
      user.generate_reset_password_token!
      token = user.reset_password_token

      patch password_reset_path(token), params: {
        user: {
          password_confirmation: ""
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("パスワードを入力してください")
      expect(user.reload.valid_password?("password")).to be(true)
      expect(user.reset_password_token).to eq(token)
    end

    it "確認用パスワードが空の場合は変更しない" do
      user.generate_reset_password_token!

      patch password_reset_path(user.reset_password_token), params: {
        user: {
          password: "new-password",
          password_confirmation: ""
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("パスワード（確認用）を入力してください")
      expect(user.reload.valid_password?("password")).to be(true)
    end

    it "パスワードと確認用パスワードが不一致の場合は変更しない" do
      user.generate_reset_password_token!

      patch password_reset_path(user.reset_password_token), params: {
        user: {
          password: "new-password",
          password_confirmation: "different"
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("パスワード（確認用）とパスワードの入力が一致しません")
      expect(user.reload.valid_password?("password")).to be(true)
    end

    it "3文字未満のパスワードの場合は変更しない" do
      user.generate_reset_password_token!

      patch password_reset_path(user.reset_password_token), params: {
        user: {
          password: "ab",
          password_confirmation: "ab"
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("パスワードは3文字以上で入力してください")
      expect(user.reload.valid_password?("password")).to be(true)
    end
  end
end
