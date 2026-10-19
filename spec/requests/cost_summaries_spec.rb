require "rails_helper"

RSpec.describe "費用集計の表示", type: :request do
  let(:cost_items_attributes) do
    {
      "0" => { name: "家賃", category: "rent", amount: 100_000, status: "confirmed" },
      "1" => { name: "引っ越し業者費用", category: "moving", amount: "", status: "unchecked" },
      "2" => { name: "手続き費用", category: "other", amount: 0, status: "unchecked" }
    }
  end

  { "予算内" => 300_000, "予算超過" => 50_000, "予算未入力" => "" }.each do |condition, budget|
    it "#{condition}でも未確認項目の件数と確認案内、合計が未確定であることを表示すること" do
      calculate_costs(budget: budget)

      expect(response).to have_http_status(:ok)
      expect(document.text).to include("未確認の費用項目が2件あります。")
      expect(document.text).to include("未確認項目の金額を確認してください。")
      expect(document.text).to include("金額未入力の項目があるため、表示中の合計は最終総額ではありません。")
    end
  end

  it "内訳に金額未入力と0円の項目を表示し、合計とグラフは入力済み金額で集計すること" do
    calculate_costs(budget: 300_000)

    expect(item_row("引っ越し業者費用").text).to include("金額未入力")
    expect(item_row("手続き費用").text).to include("0円")
    expect(item_row("手続き費用").text).not_to include("金額未入力")
    expect(document.text).to include("100,000円")
    expect(chart_amounts).to eq([ 100_000, 0, 0, 0 ])
  end

  it "金額未入力がなくても未確認の状態なら確認案内を表示し、合計未確定の案内は表示しないこと" do
    cost_items_attributes["1"][:amount] = 50_000

    calculate_costs(budget: 300_000)

    expect(document.text).to include("未確認の費用項目が2件あります。")
    expect(document.text).not_to include("表示中の合計は最終総額ではありません。")
    expect(chart_amounts).to eq([ 100_000, 50_000, 0, 0 ])
  end

  it "概算項目の集計とグラフの注意書きを維持すること" do
    cost_items_attributes["1"].merge!(amount: 50_000, status: "estimated")

    calculate_costs(budget: 300_000)

    expect(item_row("引っ越し業者費用").text).to include("概算")
    expect(chart_amounts).to eq([ 100_000, 50_000, 0, 0 ])
    expect(document.text).to include("正式な金額に更新すると内訳が変わる可能性があります。")
  end

  it "保存済みリストでも金額未入力と0円を区別し、状態を更新できること" do
    user = User.create!(
      name: "内訳確認ユーザー",
      email: "summary@example.com",
      password: "password",
      password_confirmation: "password"
    )
    cost_list = user.cost_lists.create!(
      title: "確認中の費用",
      budget: 300_000,
      cost_items_attributes: cost_items_attributes
    )
    post login_path, params: { email: user.email, password: "password" }

    get cost_list_path(cost_list)

    expect(response).to have_http_status(:ok)
    expect(document.text).to include("未確認の費用項目が2件あります。")
    expect(item_row("引っ越し業者費用").text).to include("金額未入力")
    expect(item_row("手続き費用").text).to include("0円")
    expect(item_row("引っ越し業者費用").at_css("select[name='cost_item[status]']")).to be_present
    expect(item_row("手続き費用").at_css("select[name='cost_item[status]']")).to be_present
  end

  def calculate_costs(budget:)
    post cost_lists_path, params: {
      cost_list: { budget: budget, cost_items_attributes: cost_items_attributes }
    }
    follow_redirect!
  end

  def document
    @document ||= Nokogiri::HTML(response.body)
  end

  def item_row(name)
    document.css("details .border-bottom").find do |row|
      row.at_css(".fw-semibold").text.strip == name
    end
  end

  def chart_amounts
    JSON.parse(document.at_css("canvas")["data-cost-breakdown-chart-amounts-value"])
  end
end
