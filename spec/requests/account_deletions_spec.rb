require "rails_helper"

RSpec.describe "アカウント削除", type: :request do
  let(:password) { "password" }
  let(:user) do
    User.create!(
      name: "退会テストユーザー",
      email: "account-deletion@example.com",
      password:,
      password_confirmation: password
    )
  end
  let(:all_confirmations) do
    {
      user_information_confirmed: "true",
      google_authentication_confirmed: "true",
      cost_data_confirmed: "true",
      irreversible_confirmed: "true"
    }
  end

  def login_as(user, password: "password")
    post login_path, params: { email: user.email, password: }
  end

  def create_cost_data_for(user, title: "削除対象リスト")
    cost_list = user.cost_lists.create!(
      title:,
      budget: 300_000,
      memo: "駅に近い物件を優先する"
    )
    cost_item = cost_list.cost_items.create!(
      name: "家賃",
      category: :rent,
      status: :confirmed,
      amount: 70_000
    )

    [ cost_list, cost_item ]
  end

  def convert_to_google_only(user)
    user.authentications.create!(provider: "google", uid: "google-only-#{user.id}")
    user.update_columns(crypted_password: nil, salt: nil)
  end

  def deletion_params(password: "password", confirmations: all_confirmations)
    {
      account_deletion: confirmations.merge(current_password: password)
    }
  end

  describe "GET /account_deletion" do
    it "未ログインでは退会確認画面を開けない" do
      get account_deletion_path

      expect(response).to redirect_to(login_path)
      expect(flash[:alert]).to eq("ログインしてください")
    end

    it "GETではユーザーを削除しない" do
      login_as(user)

      expect { get account_deletion_path }.not_to change(User, :count)

      expect(response).to have_http_status(:ok)
    end

    it "マイページの危険操作エリアから退会確認画面へ移動できる" do
      login_as(user)

      get mypage_path

      expect(response.body).to include("アカウントの削除")
      expect(response.body).to include("退会手続きへ")
      expect(response.body).to include(account_deletion_path)
    end

    it "通常ユーザーには現在のパスワード入力を表示する" do
      user.authentications.create!(provider: "google", uid: "password-user-google-uid")
      login_as(user)

      get account_deletion_path

      document = Nokogiri::HTML(response.body)
      delete_button = document.at_css("button[data-turbo-submits-with='削除中…']")
      confirmation_checkboxes = document.css(
        "input[type='checkbox'][data-account-deletion-target='confirmation']"
      )

      expect(response.body).to include("現在のパスワード")
      expect(document.at_css(
        "input[name='account_deletion[current_password]'][type='password']"
      )).to be_present
      expect(confirmation_checkboxes.size).to eq(4)
      expect(confirmation_checkboxes).to all(satisfy { |checkbox| checkbox["checked"].nil? })
      expect(delete_button).to be_present
      expect(delete_button["disabled"]).to eq("disabled")
      expect(response.body).to include("Googleアカウント自体は削除されません")
      expect(response.body).to include("過去のデータは復元されません")
    end

    it "Google専用ユーザーにはパスワード入力を表示しない" do
      login_as(user)
      convert_to_google_only(user)

      get account_deletion_path

      document = Nokogiri::HTML(response.body)

      expect(response).to have_http_status(:ok)
      expect(document.at_css("input[name='account_deletion[current_password]']")).to be_nil
      expect(document.css("input[type='checkbox']").size).to eq(4)
    end
  end

  describe "DELETE /account_deletion" do
    it "未ログインでは削除処理を実行できない" do
      user

      expect do
        delete account_deletion_path, params: deletion_params
      end.not_to change(User, :count)

      expect(response).to redirect_to(login_path)
      expect(user.reload).to be_present
    end

    context "通常ユーザー" do
      before do
        login_as(user)
      end

      it "全項目チェック済みと正しいパスワードでUserと全関連データを削除する" do
        authentication = user.authentications.create!(provider: "google", uid: "deletion-google-uid")
        cost_list, cost_item = create_cost_data_for(user)
        user.update_columns(
          reset_password_token: "deletion-reset-token",
          reset_password_token_expires_at: 1.hour.from_now,
          reset_password_email_sent_at: Time.current
        )

        delete account_deletion_path, params: deletion_params

        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to eq("退会手続きが完了しました")
        expect(User.exists?(user.id)).to be(false)
        expect(Authentication.exists?(authentication.id)).to be(false)
        expect(CostList.exists?(cost_list.id)).to be(false)
        expect(CostItem.exists?(cost_item.id)).to be(false)

        get mypage_path
        expect(response).to redirect_to(login_path)

        get account_deletion_path
        expect(response).to redirect_to(login_path)
      end

      it "現在のパスワードが空の場合は削除しない" do
        delete account_deletion_path, params: deletion_params(password: "")

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("現在のパスワードを入力してください")
        expect(User.exists?(user.id)).to be(true)
      end

      it "現在のパスワードが不正な場合は削除しない" do
        delete account_deletion_path, params: deletion_params(password: "wrong-password")

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("現在のパスワードが正しくありません")
        expect(User.exists?(user.id)).to be(true)
      end

      it "全項目が未チェックの場合は削除しない" do
        delete account_deletion_path, params: deletion_params(confirmations: {})

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("すべての確認項目にチェックを入れてください")
        expect(User.exists?(user.id)).to be(true)
      end

      it "1項目でも未チェックならチェック状態を保持し、全関連データを残す" do
        authentication = user.authentications.create!(provider: "google", uid: "unchecked-google-uid")
        cost_list, cost_item = create_cost_data_for(user, title: "未チェック時のデータ")
        incomplete_confirmations = all_confirmations.merge(cost_data_confirmed: "false")

        delete account_deletion_path,
               params: deletion_params(confirmations: incomplete_confirmations)

        document = Nokogiri::HTML(response.body)
        checked_fields = document.css("input[type='checkbox'][checked]").map { |input| input["name"] }
        password_input = document.at_css("input[name='account_deletion[current_password]']")

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("すべての確認項目にチェックを入れてください")
        expect(checked_fields).to contain_exactly(
          "account_deletion[user_information_confirmed]",
          "account_deletion[google_authentication_confirmed]",
          "account_deletion[irreversible_confirmed]"
        )
        expect(password_input["value"]).to be_nil
        expect(User.exists?(user.id)).to be(true)
        expect(Authentication.exists?(authentication.id)).to be(true)
        expect(CostList.exists?(cost_list.id)).to be(true)
        expect(CostItem.exists?(cost_item.id)).to be(true)
      end

      it "削除後は同じメールアドレスで再登録でき、退会前のセッションデータを引き継がない" do
        post cost_lists_path, params: {
          cost_list: {
            budget: 100_000,
            cost_items_attributes: {
              "0" => { name: "家賃", category: "rent", amount: 50_000, status: "estimated" }
            }
          }
        }

        delete account_deletion_path, params: deletion_params

        post users_path, params: {
          user: {
            name: "再登録ユーザー",
            email: user.email,
            password: "new-password",
            password_confirmation: "new-password"
          }
        }

        new_user = User.find_by!(email: user.email)
        expect(response).to redirect_to(mypage_path)
        expect(new_user.cost_lists).to be_empty
      end
    end

    context "Googleログイン専用ユーザー" do
      before do
        login_as(user)
        convert_to_google_only(user)
      end

      it "全項目チェック済みならパスワードなしで退会できる" do
        authentication = user.authentications.find_by!(provider: "google")

        delete account_deletion_path, params: deletion_params(password: nil)

        expect(response).to redirect_to(root_path)
        expect(User.exists?(user.id)).to be(false)
        expect(Authentication.exists?(authentication.id)).to be(false)
      end

      it "パスワードを送信しなくても退会できる" do
        delete account_deletion_path, params: deletion_params(password: "")

        expect(response).to redirect_to(root_path)
        expect(User.exists?(user.id)).to be(false)
      end

      it "1項目でも未チェックなら削除しない" do
        incomplete_confirmations = all_confirmations.merge(irreversible_confirmed: "false")

        delete account_deletion_path,
               params: deletion_params(password: nil, confirmations: incomplete_confirmations)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("すべての確認項目にチェックを入れてください")
        expect(User.exists?(user.id)).to be(true)
      end
    end

    context "安全性" do
      it "他ユーザーとその費用データを削除しない" do
        other_user = User.create!(
          name: "削除されないユーザー",
          email: "account-deletion-other@example.com",
          password:,
          password_confirmation: password
        )
        other_cost_list, other_cost_item = create_cost_data_for(other_user, title: "他ユーザーのリスト")
        login_as(user)

        delete account_deletion_path,
               params: {
                 user_id: other_user.id,
                 account_deletion: all_confirmations.merge(current_password: password)
               }

        expect(User.exists?(user.id)).to be(false)
        expect(User.exists?(other_user.id)).to be(true)
        expect(CostList.exists?(other_cost_list.id)).to be(true)
        expect(CostItem.exists?(other_cost_item.id)).to be(true)
      end

      it "削除失敗時は全データをロールバックし、ログイン状態を維持する" do
        authentication = user.authentications.create!(provider: "google", uid: "rollback-google-uid")
        cost_list, cost_item = create_cost_data_for(user, title: "ロールバック対象")
        login_as(user)
        allow_any_instance_of(User).to receive(:destroy!).and_wrap_original do |original|
          original.receiver.cost_lists.first.destroy!
          raise "sensitive database failure"
        end

        delete account_deletion_path, params: deletion_params

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("退会手続きを完了できませんでした")
        expect(response.body).not_to include("sensitive database failure")
        expect(User.exists?(user.id)).to be(true)
        expect(Authentication.exists?(authentication.id)).to be(true)
        expect(CostList.exists?(cost_list.id)).to be(true)
        expect(CostItem.exists?(cost_item.id)).to be(true)

        get mypage_path
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
