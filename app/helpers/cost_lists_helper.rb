module CostListsHelper
  def cost_list_error_messages(cost_list)
    # 子項目のエラーは、カテゴリと行番号を添えて別に表示する。
    messages = cost_list.errors.reject { |error| error.attribute.to_s.start_with?("cost_items") }
                        .map(&:full_message)

    cost_list.cost_items.reject(&:marked_for_destruction?).group_by(&:category).each do |category, items|
      items.each_with_index do |item, index|
        label = "#{t("enums.cost_item.category.#{category}")} #{index + 1}行目"
        item.errors.full_messages.each { |message| messages << "#{label}：#{message}" }
      end
    end

    messages
  end
end
