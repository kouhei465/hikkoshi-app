class CreateCostListDrafts < ActiveRecord::Migration[7.2]
  def change
    create_table :cost_list_drafts do |t|
      t.references :user, foreign_key: true
      t.jsonb :data, null: false, default: {}
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :cost_list_drafts, :token_digest, unique: true
    add_index :cost_list_drafts, :expires_at
  end
end
