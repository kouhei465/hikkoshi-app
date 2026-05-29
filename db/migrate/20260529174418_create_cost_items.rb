class CreateCostItems < ActiveRecord::Migration[7.2]
  def change
    create_table :cost_items do |t|
      t.references :cost_list, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :category, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.integer :amount

      t.timestamps
    end
  end
end
