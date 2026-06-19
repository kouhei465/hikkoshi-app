require "test_helper"

class CostListsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get new_cost_list_url
    assert_response :success
  end

  test "renders one name datalist per category and text fields referencing it" do
    get new_cost_list_url

    CostItem.categories.each_key do |category|
      assert_select "datalist#cost-item-name-options-#{category}", count: 1
      assert_select "input[list='cost-item-name-options-#{category}']", count: 2
    end

    assert_select "select[name$='[name]']", count: 0
    assert_select "[data-nested-form-target='customNameEstimateMessage']"
  end
end
