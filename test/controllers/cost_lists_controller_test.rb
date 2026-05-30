require "test_helper"

class CostListsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get new_cost_list_url
    assert_response :success
  end
end
