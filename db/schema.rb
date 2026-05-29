# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2026_05_29_174418) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "cost_items", force: :cascade do |t|
    t.bigint "cost_list_id", null: false
    t.string "name", null: false
    t.integer "category", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.integer "amount"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cost_list_id"], name: "index_cost_items_on_cost_list_id"
  end

  create_table "cost_lists", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "title", null: false
    t.text "memo"
    t.integer "budget"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_cost_lists_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.string "crypted_password"
    t.string "salt"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "cost_items", "cost_lists"
  add_foreign_key "cost_lists", "users"
end
