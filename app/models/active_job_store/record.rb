# frozen_string_literal: true

module ActiveJobStore
  class Record < ApplicationRecord
    self.table_name = 'active_job_store'

    serialize :arguments, JSON
    serialize :custom_data, JSON
    serialize :details, JSON
    serialize :result, JSON

    enum state: { initialized: 0, enqueued: 1, started: 2, completed: 3, error: 4 }

    scope :by_arguments, ->(*args) { where('arguments = ?', args.to_json) }
    scope :performing, -> { where(state: %i[enqueued started]) }
  end
end
