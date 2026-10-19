class CostListDraft < ApplicationRecord
  EXPIRATION = 24.hours

  belongs_to :user, optional: true

  validates :token_digest, :expires_at, presence: true

  scope :active, -> { where("expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at <= ?", Time.current) }

  def self.create_for(attributes:, user: nil)
    token = SecureRandom.urlsafe_base64(32)
    draft = create!(
      data: attributes,
      user: user,
      token_digest: Digest::SHA256.hexdigest(token),
      expires_at: EXPIRATION.from_now
    )

    [ draft, token ]
  end

  def self.find_for(token:, user: nil)
    return if token.blank?

    draft = active.find_by(token_digest: Digest::SHA256.hexdigest(token))
    return unless draft && (draft.user_id.nil? || draft.user_id == user&.id)

    draft
  end

  def refresh!(attributes:)
    update!(data: attributes, expires_at: EXPIRATION.from_now)
  end

  def claim!(user:)
    if user.nil? || (user_id.present? && user_id != user.id)
      raise ActiveRecord::RecordNotFound
    end

    # 認証前のCookieに含まれるトークンでは、認証後の入力を参照できなくする。
    token = SecureRandom.urlsafe_base64(32)
    update!(user: user, token_digest: Digest::SHA256.hexdigest(token), expires_at: EXPIRATION.from_now)
    token
  end
end
