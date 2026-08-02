require "rails_helper"

RSpec.describe Authentication, type: :model do
  let(:user) do
    User.create!(
      name: "認証テストユーザー",
      email: "authentication@example.com",
      password: "password",
      password_confirmation: "password"
    )
  end

  it "ユーザー、provider、uidがあれば有効である" do
    authentication = described_class.new(user:, provider: "google", uid: "authentication-uid")

    expect(authentication).to be_valid
  end

  it "providerとuidの組み合わせは重複できない" do
    described_class.create!(user:, provider: "google", uid: "duplicate-uid")
    duplicate = described_class.new(user:, provider: "google", uid: "duplicate-uid")

    expect(duplicate).to be_invalid
  end

  it "ユーザーを削除すると認証情報も削除される" do
    described_class.create!(user:, provider: "google", uid: "dependent-destroy-uid")

    expect { user.destroy! }.to change(described_class, :count).by(-1)
  end
end
