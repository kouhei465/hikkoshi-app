class CreateCostLists < ActiveRecord::Migration[7.2]
  def change
    create_table :cost_lists do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.text :memo
      t.integer :budget

      t.timestamps
    end
  end
end
