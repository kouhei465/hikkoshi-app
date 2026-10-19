namespace :cost_list_drafts do
  desc "期限切れの費用入力の一時データを削除する"
  task cleanup: :environment do
    deleted_count = CostListDraft.expired.delete_all
    puts "期限切れの一時データを#{deleted_count}件削除しました。"
  end
end
