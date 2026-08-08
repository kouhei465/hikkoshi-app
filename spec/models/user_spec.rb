require "rails_helper"

RSpec.describe User, type: :model do
  describe "メールアドレスの正規化" do
    let(:password_attributes) do
      {
        name: "正規化テストユーザー",
        password: "password",
        password_confirmation: "password"
      }
    end

    it "大文字を含むメールアドレスを小文字にして保存する" do
      user = described_class.create!(password_attributes.merge(email: "User@Example.COM"))

      expect(user.reload.email).to eq("user@example.com")
    end

    it "メールアドレスの前後の空白を除去して保存する" do
      user = described_class.create!(password_attributes.merge(email: "  user@example.com  "))

      expect(user.reload.email).to eq("user@example.com")
    end

    it "nilは正規化時にもnilのまま扱う" do
      user = described_class.new(password_attributes.merge(email: nil))

      expect(described_class.normalize_value_for(:email, nil)).to be_nil
      expect(user.email).to be_nil
      expect(user).to be_invalid
    end
  end

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

    it "大文字小文字だけが異なるメールアドレスは重複登録できない" do
      described_class.create!(valid_attributes)
      duplicate_user = described_class.new(
        valid_attributes.merge(name: "別のユーザー", email: "TEST@EXAMPLE.COM")
      )

      expect(duplicate_user).to be_invalid
      expect(duplicate_user.errors[:email]).to be_present
    end

    it "パスワードが8文字の場合は有効になる" do
      user = described_class.new(
        valid_attributes.merge(
          password: "12345678",
          password_confirmation: "12345678"
        )
      )

      expect(user).to be_valid
    end

    it "パスワードが7文字の場合は無効になる" do
      user = described_class.new(
        valid_attributes.merge(
          password: "1234567",
          password_confirmation: "1234567"
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

    it "通常登録ではパスワードなしの新規ユーザーを登録できない" do
      user = described_class.new(name: "通常ユーザー", email: "without-password@example.com")

      expect(user).to be_invalid
      expect(user.errors[:password]).to be_present
    end

    it "Google認証を持つ新規ユーザーはパスワードなしで登録できる" do
      user = described_class.new(name: "Googleユーザー", email: "google-model@example.com")
      user.authentications.build(provider: "google", uid: "google-model-uid")

      expect(user.save).to be(true)
      expect(user.crypted_password).to be_nil
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

    it "パスワードが7文字の場合は変更できない" do
      user.password_confirmation = "1234567"

      expect(user.change_password("1234567")).to be(false)
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

    it "複数の外部認証を持ち、ユーザー削除時に削除する設定になっている" do
      association = described_class.reflect_on_association(:authentications)

      expect(association.macro).to eq(:has_many)
      expect(association.options[:dependent]).to eq(:destroy)
    end

    it "ユーザーを削除すると認証情報、費用リスト、費用項目も削除する" do
      user = described_class.create!(
        name: "関連削除ユーザー",
        email: "dependent-destroy@example.com",
        password: "password",
        password_confirmation: "password"
      )
      authentication = user.authentications.create!(provider: "google", uid: "user-dependent-uid")
      cost_list = user.cost_lists.create!(title: "関連削除リスト")
      cost_item = cost_list.cost_items.create!(name: "家賃", category: :rent, status: :confirmed)

      user.destroy!

      expect(Authentication.exists?(authentication.id)).to be(false)
      expect(CostList.exists?(cost_list.id)).to be(false)
      expect(CostItem.exists?(cost_item.id)).to be(false)
    end
  end
end
