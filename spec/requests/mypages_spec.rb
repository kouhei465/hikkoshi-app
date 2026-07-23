require "rails_helper"

RSpec.describe "マイページ", type: :request do
  describe "GET /mypage" do
    context "未ログインの場合" do
      it "ログインページにリダイレクトされること" do
        get mypage_path

        expect(response).to redirect_to(login_path)
        expect(flash[:alert]).to eq("ログインしてください")
      end
    end

    context "ログイン済みの場合" do
      it "複数の費用リストと各操作への導線が表示されること" do
        user = User.create!(
          name: "一覧テストユーザー",
          email: "mypage@example.com",
          password: "password",
          password_confirmation: "password"
        )
        first_cost_list = user.cost_lists.create!(title: "A物件の費用")
        second_cost_list = user.cost_lists.create!(title: "B物件の費用")

        post login_path, params: {
          email: user.email,
          password: "password"
        }

        get mypage_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("A物件の費用")
        expect(response.body).to include("B物件の費用")
        expect(response.body).to include("詳細を見る")
        expect(response.body).to include("編集する")
        expect(response.body).to include("名前を変更")
        expect(response.body).to include("削除する")
        expect(response.body).to include(update_title_cost_list_path(first_cost_list))
        expect(response.body).to include(update_title_cost_list_path(second_cost_list))

        document = Nokogiri::HTML(response.body)
        compare_form = document.at_css(
          "form[action='#{compare_cost_lists_path}'][method='get']"
        )
        checkboxes = document.xpath(
          "//input[@type='checkbox' and @name='cost_list_ids[]']"
        )
        modal_ids = response.body.scan(/id="(rename-cost-list-modal-\d+)"/).flatten

        expect(compare_form).to be_present
        expect(compare_form["id"]).to eq("cost-list-compare-form")
        expect(checkboxes.map { |checkbox| checkbox["value"] }).to contain_exactly(
          first_cost_list.id.to_s,
          second_cost_list.id.to_s
        )
        expect(checkboxes).to all(
          satisfy { |checkbox| checkbox["form"] == "cost-list-compare-form" }
        )
        expect(document.text).to include("比較する費用リストを2件選択してください。")
        expect(compare_form.at_xpath(
          ".//button[@type='submit' and normalize-space()='選択した2件を比較する']"
        )).to be_present
        expect(modal_ids).to contain_exactly(
          "rename-cost-list-modal-#{first_cost_list.id}",
          "rename-cost-list-modal-#{second_cost_list.id}"
        )
      end

      it "保存済みリストが2件未満の場合は案内を表示して比較ボタンを無効にすること" do
        user = User.create!(
          name: "比較案内テストユーザー",
          email: "mypage-compare-guide@example.com",
          password: "password",
          password_confirmation: "password"
        )
        user.cost_lists.create!(title: "A物件の費用")

        post login_path, params: { email: user.email, password: "password" }

        get mypage_path

        document = Nokogiri::HTML(response.body)
        disabled_button = document.at_xpath(
          "//button[@type='submit' and normalize-space()='選択した2件を比較する' and @disabled]"
        )

        expect(response.body).to include("比較するには費用リストを2件以上保存してください。")
        expect(disabled_button).to be_present
      end
    end
  end
end
