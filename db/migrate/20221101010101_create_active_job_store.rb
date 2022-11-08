# frozen_string_literal: true

class CreateActiveJobStore < ActiveRecord::Migration[6.0]
  def change
    create_table :active_job_store do |t|
      t.string :job_id, null: false
      t.string :job_class, null: false
      t.integer :state, null: false
      t.text :arguments
      t.text :custom_data
      t.text :details
      t.text :result
      t.string :exception
      t.datetime :enqueued_at
      t.datetime :started_at
      t.datetime :completed_at
      t.datetime :created_at
    end

    add_index :active_job_store, [:job_class, :job_id], unique: true
    add_index :active_job_store, [:job_class, :state]
  end
end
