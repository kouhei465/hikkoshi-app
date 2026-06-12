require "test_helper"

class CostItemTest < ActiveSupport::TestCase
  test "returns name options for category" do
    assert_includes CostItem.name_options_for(:rent), "家賃"
    assert_includes CostItem.name_options_for("moving"), "引っ越し業者費用"
  end

  test "returns empty array for unknown category" do
    assert_equal [], CostItem.name_options_for("unknown")
  end

  test "returns reference estimate amount for non-rent category" do
    cost_item = CostItem.new(category: :moving)

    assert_equal 50_000, cost_item.reference_estimate_amount
  end

  test "does not return reference estimate amount for rent category" do
    cost_item = CostItem.new(category: :rent)

    assert_nil cost_item.reference_estimate_amount
  end
end
