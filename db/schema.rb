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

ActiveRecord::Schema.define(version: 20170320134812) do

  create_table "catalogues", force: :cascade do |t|
    t.string   "url"
    t.string   "lims_id"
    t.string   "pipeline"
    t.boolean  "current"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["lims_id"], name: "index_catalogues_on_lims_id"
  end

  create_table "products", force: :cascade do |t|
    t.string   "name"
    t.datetime "created_at",                 null: false
    t.datetime "updated_at",                 null: false
    t.integer  "catalogue_id"
    t.integer  "TAT"
    t.integer  "cost_per_sample"
    t.string   "requested_biomaterial_type"
    t.integer  "product_version"
    t.string   "availability"
    t.string   "description"
    t.index ["catalogue_id"], name: "index_products_on_catalogue_id"
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
    t.index ["product_id"], name: "index_work_orders_on_product_id"
  end

end
