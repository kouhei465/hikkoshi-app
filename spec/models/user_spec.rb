require "rails_helper"

RSpec.describe User, type: :model do
  describe "バリデーション" do
    let(:valid_attributes) do
      {
        name: "テストユーザー",
        email: "test@example.com",
        password: "password",
        password_confirmation: "password"
      }
    end

    it "有効な属性の場合は登録できる" do
      user = described_class.new(valid_attributes)

      expect(user).to be_valid
    end

    it "有効な属性の場合は通常の新規登録を保存できる" do
      user = described_class.new(valid_attributes)

      expect(user.save).to be(true)
    end

    it "名前が空の場合は無効になる" do
      user = described_class.new(valid_attributes.merge(name: nil))

      expect(user).to be_invalid
    end

    it "名前が255文字の場合は有効になる" do
      user = described_class.new(valid_attributes.merge(name: "a" * 255))

      expect(user).to be_valid
    end

    it "名前が256文字以上の場合は無効になる" do
      user = described_class.new(valid_attributes.merge(name: "a" * 256))

      expect(user).to be_invalid
    end

    it "メールアドレスが空の場合は無効になる" do
      user = described_class.new(valid_attributes.merge(email: nil))

      expect(user).to be_invalid
    end

    it "同じメールアドレスが登録済みの場合は無効になる" do
      described_class.create!(valid_attributes)

      duplicate_user = described_class.new(
        valid_attributes.merge(name: "別のユーザー")
      )

      expect(duplicate_user).to be_invalid
    end

    it "パスワードが3文字以上の場合は有効になる" do
      user = described_class.new(
        valid_attributes.merge(
          password: "abc",
          password_confirmation: "abc"
        )
      )

      expect(user).to be_valid
    end

    it "パスワードが2文字以下の場合は無効になる" do
      user = described_class.new(
        valid_attributes.merge(
          password: "ab",
          password_confirmation: "ab"
        )
      )

      expect(user).to be_invalid
    end

    it "パスワードと確認用パスワードが一致しない場合は無効になる" do
      user = described_class.new(
        valid_attributes.merge(password_confirmation: "different")
      )

      expect(user).to be_invalid
    end

    it "確認用パスワードが空の場合は無効になる" do
      user = described_class.new(
        valid_attributes.merge(password_confirmation: nil)
      )

      expect(user).to be_invalid
    end
  end

  describe "パスワード変更" do
    let(:user) do
      described_class.create!(
        name: "パスワード変更ユーザー",
        email: "password-change@example.com",
        password: "password",
        password_confirmation: "password"
      )
    end

    it "空のパスワードでは変更できない" do
      crypted_password = user.crypted_password
      user.password_confirmation = ""

      expect(user.change_password("")).to be(false)
      expect(user.reload.crypted_password).to eq(crypted_password)
    end

    it "確認用パスワードが空の場合は変更できない" do
      user.password_confirmation = ""

      expect(user.change_password("new-password")).to be(false)
      expect(user.errors[:password_confirmation]).to be_present
    end

    it "パスワードと確認用パスワードが一致しない場合は変更できない" do
      user.password_confirmation = "different"

      expect(user.change_password("new-password")).to be(false)
      expect(user.errors[:password_confirmation]).to be_present
    end

    it "パスワードが3文字未満の場合は変更できない" do
      user.password_confirmation = "ab"

      expect(user.change_password("ab")).to be(false)
      expect(user.errors[:password]).to be_present
    end

    it "有効なパスワードへ変更できる" do
      user.password_confirmation = "new-password"

      expect(user.change_password("new-password")).to be(true)
      expect(user.reload.valid_password?("new-password")).to be(true)
    end
  end

  describe "関連付け" do
    it "複数の費用リストを持つ" do
      association = described_class.reflect_on_association(:cost_lists)

      expect(association.macro).to eq(:has_many)
    end

    it "ユーザー削除時に関連する費用リストも削除する設定になっている" do
      association = described_class.reflect_on_association(:cost_lists)

      expect(association.options[:dependent]).to eq(:destroy)
    end
  end
end
