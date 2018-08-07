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

ActiveRecord::Schema.define(version: 2018_08_07_150205) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "plpgsql"
  enable_extension "uuid-ossp"

  create_table "aker_process_module_pairings", id: :serial, force: :cascade do |t|
    t.integer "from_step_id"
    t.integer "to_step_id"
    t.boolean "default_path", null: false
    t.integer "aker_process_id"
    t.index ["aker_process_id"], name: "index_aker_process_module_pairings_on_aker_process_id"
    t.index ["from_step_id", "to_step_id", "aker_process_id"], name: "index_on_aker_pairings", unique: true
    t.index ["from_step_id"], name: "index_aker_process_module_pairings_on_from_step_id"
    t.index ["to_step_id"], name: "index_aker_process_module_pairings_on_to_step_id"
  end

  create_table "aker_process_modules", id: :serial, force: :cascade do |t|
    t.string "name", null: false
    t.integer "aker_process_id"
    t.integer "min_value"
    t.integer "max_value"
    t.index ["aker_process_id", "name"], name: "index_aker_process_modules_on_aker_process_id_and_name", unique: true
    t.index ["aker_process_id"], name: "index_aker_process_modules_on_aker_process_id"
  end

  create_table "aker_processes", id: :serial, force: :cascade do |t|
    t.string "name", null: false
    t.integer "TAT"
    t.uuid "uuid", null: false
    t.integer "process_class"
  end

  create_table "aker_product_processes", id: :serial, force: :cascade do |t|
    t.integer "product_id"
    t.integer "aker_process_id"
    t.integer "stage", null: false
    t.index ["aker_process_id"], name: "index_aker_product_processes_on_aker_process_id"
    t.index ["product_id"], name: "index_aker_product_processes_on_product_id"
  end

  create_table "catalogues", id: :serial, force: :cascade do |t|
    t.string "url"
    t.citext "lims_id", null: false
    t.string "pipeline"
    t.boolean "current"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["lims_id"], name: "index_catalogues_on_lims_id"
  end

  create_table "data_release_strategies", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "name"
    t.string "study_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["id"], name: "index_data_release_strategies_on_id", unique: true
  end

  create_table "jobs", id: :serial, force: :cascade do |t|
    t.uuid "container_uuid"
    t.datetime "started"
    t.datetime "completed"
    t.datetime "cancelled"
    t.datetime "broken"
    t.bigint "work_order_id", null: false
    t.string "close_comment"
    t.uuid "set_uuid"
    t.uuid "uuid", default: -> { "uuid_generate_v4()" }, null: false
    t.uuid "input_set_uuid"
    t.index ["work_order_id"], name: "index_jobs_on_work_order_id"
  end

  create_table "permissions", id: :serial, force: :cascade do |t|
    t.citext "permitted", null: false
    t.string "accessible_type", null: false
    t.integer "accessible_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "permission_type", null: false
    t.index ["accessible_type", "accessible_id"], name: "index_permissions_on_accessible_type_and_accessible_id"
    t.index ["permitted", "permission_type", "accessible_id", "accessible_type"], name: "index_permissions_on_various", unique: true
    t.index ["permitted"], name: "index_permissions_on_permitted"
  end

  create_table "products", id: :serial, force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "catalogue_id"
    t.string "requested_biomaterial_type"
    t.integer "product_version"
    t.string "description"
    t.boolean "availability", default: true, null: false
    t.uuid "uuid", null: false
    t.index ["catalogue_id"], name: "index_products_on_catalogue_id"
  end

  create_table "work_order_module_choices", id: :serial, force: :cascade do |t|
    t.integer "work_order_id"
    t.integer "aker_process_modules_id"
    t.integer "position"
    t.integer "selected_value"
    t.index ["aker_process_modules_id"], name: "index_work_order_module_choices_on_aker_process_modules_id"
    t.index ["work_order_id"], name: "index_work_order_module_choices_on_work_order_id"
  end

  create_table "work_orders", id: :serial, force: :cascade do |t|
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "total_cost", precision: 8, scale: 2
    t.decimal "cost_per_sample", precision: 8, scale: 2
    t.boolean "material_updated", default: false, null: false
    t.integer "order_index", null: false
    t.datetime "dispatch_date"
    t.datetime "completion_date"
    t.uuid "original_set_uuid"
    t.uuid "set_uuid"
    t.uuid "finished_set_uuid"
    t.uuid "work_order_uuid", null: false
    t.bigint "work_plan_id", null: false
    t.bigint "process_id", null: false
    t.index ["process_id"], name: "index_work_orders_on_process_id"
    t.index ["work_plan_id"], name: "index_work_orders_on_work_plan_id"
  end

  create_table "work_plans", id: :serial, force: :cascade do |t|
    t.integer "project_id"
    t.bigint "product_id"
    t.uuid "original_set_uuid"
    t.citext "owner_email", null: false
    t.string "comment"
    t.uuid "uuid", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "cancelled"
    t.uuid "data_release_strategy_id"
    t.string "priority", default: "standard", null: false
    t.index ["data_release_strategy_id"], name: "index_work_plans_on_data_release_strategy_id"
    t.index ["owner_email"], name: "index_work_plans_on_owner_email"
    t.index ["product_id"], name: "index_work_plans_on_product_id"
  end

  add_foreign_key "aker_process_modules", "aker_processes"
  add_foreign_key "aker_product_processes", "aker_processes"
  add_foreign_key "aker_product_processes", "products"
  add_foreign_key "jobs", "work_orders"
  add_foreign_key "products", "catalogues"
  add_foreign_key "work_order_module_choices", "aker_process_modules", column: "aker_process_modules_id"
  add_foreign_key "work_order_module_choices", "work_orders"
  add_foreign_key "work_orders", "aker_processes", column: "process_id"
  add_foreign_key "work_orders", "work_plans"
  add_foreign_key "work_plans", "data_release_strategies"
  add_foreign_key "work_plans", "products"
end
