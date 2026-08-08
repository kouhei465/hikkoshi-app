class User < ApplicationRecord
  authenticates_with_sorcery!

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :name, presence: true, length: { maximum: 255 }
  validates :email,
            presence: true,
            uniqueness: { case_sensitive: false }
  validates :password, length: { minimum: 8 }, if: :password_required?
  validates :password, confirmation: true, if: :password_required?
  validates :password_confirmation, presence: true, if: :password_required?

  has_many :cost_lists, dependent: :destroy
  has_many :authentications, dependent: :destroy, inverse_of: :user

  def google_only?
    crypted_password.nil? && google_authentication?
  end

  private

  def password_required?
    !password.nil? || (new_record? && !google_authentication?)
  end

  def google_authentication?
    authentications.any? { |authentication| authentication.provider == "google" }
  end
end
