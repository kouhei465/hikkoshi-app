class GuestCostListSaver
  def self.call(user:, attributes:)
    return if attributes.blank?

    cost_list = user.cost_lists.build(attributes)
    cost_list.title = "引っ越し費用リスト" if cost_list.title.blank?

    cost_list.save
    cost_list
  end
end
