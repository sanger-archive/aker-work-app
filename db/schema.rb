# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20170410112858) do

  create_table "catalogues", force: :cascade do |t|
    t.string   "url"
    t.string   "lims_id"
    t.string   "pipeline"
    t.boolean  "current"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["lims_id"], name: "index_catalogues_on_lims_id"
  end

  create_table "permissions", force: :cascade do |t|
    t.string  "permitted"
    t.boolean "r"
    t.boolean "w"
    t.boolean "x"
    t.string  "accessible_type"
    t.integer "accessible_id"
    t.index ["accessible_type", "accessible_id"], name: "index_permissions_on_accessible_type_and_accessible_id"
    t.index ["permitted"], name: "index_permissions_on_permitted"
  end

  create_table "products", force: :cascade do |t|
    t.string   "name"
    t.datetime "created_at",                                                     null: false
    t.datetime "updated_at",                                                     null: false
    t.integer  "catalogue_id"
    t.integer  "TAT"
    t.decimal  "cost_per_sample",            precision: 8, scale: 2
    t.string   "requested_biomaterial_type"
    t.integer  "product_version"
    t.integer  "availability",                                       default: 1
    t.string   "description"
    t.index ["catalogue_id"], name: "index_products_on_catalogue_id"
  end

  create_table "users", force: :cascade do |t|
    t.string   "email",               default: "", null: false
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",       default: 0,  null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.datetime "created_at",                       null: false
    t.datetime "updated_at",                       null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  create_table "work_orders", force: :cascade do |t|
    t.string   "status"
    t.datetime "created_at",        null: false
    t.datetime "updated_at",        null: false
    t.string   "original_set_uuid"
    t.string   "set_uuid"
    t.integer  "proposal_id"
    t.string   "comment"
    t.date     "desired_date"
    t.integer  "product_id"
    t.integer  "user_id"
    t.index ["product_id"], name: "index_work_orders_on_product_id"
  end

end
