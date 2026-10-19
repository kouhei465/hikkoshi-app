require "rails_helper"
require "rake"

RSpec.describe CostListDraft, type: :model do
  include ActiveSupport::Testing::TimeHelpers

  let(:attributes) do
    {
      "title" => "引っ越しの入力途中",
      "budget" => "300000",
      "memo" => "判断メモ" * 3000,
      "cost_items_attributes" => 30.times.to_h do |index|
        [ index.to_s, { "name" => "費用項目#{index}", "amount" => "5000", "category" => "other", "status" => "unchecked" } ]
      end
    }
  end

  let(:user) { create_user("owner@example.com") }
  let(:other_user) { create_user("other@example.com") }

  def create_user(email)
    User.create!(name: "テストユーザー", email: email, password: "password", password_confirmation: "password")
  end

  describe ".create_for" do
    it "Cookieの容量を超える費用項目と長文メモをDBに保持する" do
      expect(attributes.to_json.bytesize).to be > 4096

      draft, token = described_class.create_for(attributes: attributes, user: nil)

      expect(draft.reload.data).to eq(attributes)
      expect(token.bytesize).to be < 100
      expect(draft.token_digest).to eq(Digest::SHA256.hexdigest(token))
      expect(draft.token_digest).not_to eq(token)
      expect(described_class.find_for(token: token, user: nil)).to eq(draft)
    end

    it "有効期限を24時間後に設定する" do
      freeze_time do
        draft, = described_class.create_for(attributes: attributes, user: nil)

        expect(draft.expires_at).to eq(24.hours.from_now)
      end
    end
  end

  describe ".find_for" do
    it "トークンが空または異なる場合は参照できない" do
      described_class.create_for(attributes: attributes, user: nil)

      expect(described_class.find_for(token: nil, user: nil)).to be_nil
      expect(described_class.find_for(token: "", user: nil)).to be_nil
      expect(described_class.find_for(token: "another-token", user: nil)).to be_nil
    end

    it "所有者が設定された入力は他ユーザーやゲストが参照できない" do
      draft, token = described_class.create_for(attributes: attributes, user: user)

      expect(described_class.find_for(token: token, user: user)).to eq(draft)
      expect(described_class.find_for(token: token, user: other_user)).to be_nil
      expect(described_class.find_for(token: token, user: nil)).to be_nil
    end

    it "有効期限を過ぎた入力は参照できない" do
      draft, token = described_class.create_for(attributes: attributes, user: nil)

      travel_to(draft.expires_at, with_usec: true) do
        expect(described_class.find_for(token: token, user: nil)).to be_nil
        expect(described_class.active).not_to include(draft)
        expect(described_class.expired).to include(draft)
      end
    end
  end

  describe "#refresh!" do
    it "入力内容と有効期限を更新する" do
      draft, = described_class.create_for(attributes: attributes, user: nil)
      original_expiration = draft.expires_at

      travel 1.hour do
        draft.refresh!(attributes: { "memo" => "修正した判断メモ" })

        expect(draft.reload.data).to eq("memo" => "修正した判断メモ")
        expect(draft.expires_at).to be_within(1.second).of(original_expiration + 1.hour)
      end
    end
  end

  describe "#claim!" do
    it "ログインした所有者に紐付け、ログイン前のトークンを無効にする" do
      draft, old_token = described_class.create_for(attributes: attributes, user: nil)

      new_token = draft.claim!(user: user)

      expect(draft.reload.user).to eq(user)
      expect(draft.data).to eq(attributes)
      expect(new_token).not_to eq(old_token)
      expect(described_class.find_for(token: old_token, user: user)).to be_nil
      expect(described_class.find_for(token: new_token, user: user)).to eq(draft)
      expect(described_class.find_for(token: new_token, user: other_user)).to be_nil
    end

    it "他ユーザーに所有権を移せない" do
      draft, = described_class.create_for(attributes: attributes, user: user)

      expect { draft.claim!(user: other_user) }.to raise_error(ActiveRecord::RecordNotFound)
      expect(draft.reload.user).to eq(user)
    end
  end

  describe "削除" do
    it "所有者を削除すると一時データも削除する" do
      draft, = described_class.create_for(attributes: attributes, user: user)

      user.destroy!

      expect(described_class.exists?(draft.id)).to be(false)
    end

    it "cleanupタスクは期限切れの一時データだけを削除する" do
      expired_draft, = described_class.create_for(attributes: attributes, user: nil)
      expired_draft.update!(expires_at: 1.minute.ago)
      active_draft, = described_class.create_for(attributes: attributes, user: nil)
      Rails.application.load_tasks unless Rake::Task.task_defined?("cost_list_drafts:cleanup")

      Rake::Task["cost_list_drafts:cleanup"].execute

      expect(described_class.exists?(expired_draft.id)).to be(false)
      expect(described_class.exists?(active_draft.id)).to be(true)
    end
  end
end
