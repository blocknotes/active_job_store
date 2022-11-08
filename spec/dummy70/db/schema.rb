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

ActiveRecord::Schema[7.0].define(version: 2022_11_01_010101) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_job_store", force: :cascade do |t|
    t.string "job_id", null: false
    t.string "job_class", null: false
    t.integer "state", null: false
    t.text "arguments"
    t.text "custom_data"
    t.text "details"
    t.text "result"
    t.string "exception"
    t.datetime "enqueued_at", precision: nil
    t.datetime "started_at", precision: nil
    t.datetime "completed_at", precision: nil
    t.datetime "created_at", precision: nil
    t.index ["job_class", "job_id"], name: "index_active_job_store_on_job_class_and_job_id", unique: true
    t.index ["job_class", "state"], name: "index_active_job_store_on_job_class_and_state"
  end

end
