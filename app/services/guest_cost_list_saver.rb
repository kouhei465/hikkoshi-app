class GuestCostListSaver
  def self.call(user:, attributes:)
    new(user:, attributes:).call
  end

  def initialize(user:, attributes:)
    @user = user
    @attributes = attributes
  end

  def call
    return :not_present if attributes.blank?

    cost_list = user.cost_lists.build(attributes)
    cost_list.title = "引っ越し費用リスト" if cost_list.title.blank?

    cost_list.save ? :saved : :failed
  end

  private

  attr_reader :user, :attributes
end
