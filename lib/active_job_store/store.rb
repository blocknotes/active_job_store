# frozen_string_literal: true

module ActiveJobStore
  class Store
    IGNORE_ATTRS = %w[arguments store job_id successfully_enqueued].freeze

    attr_reader :record

    def job_competed!(result:, custom_data:)
      record.update!(state: :completed, completed_at: Time.current, result: result, custom_data: custom_data)
      record
    end

    def job_enqueued!
      record.lock! # NOTE: needed to avoid update conflicts with perform when setting the state to enqueued
      yield
      record.update!(state: :enqueued, enqueued_at: Time.current)
      record
    end

    def job_failed!(exception:, custom_data:)
      record.update!(state: :error, exception: exception.inspect, custom_data: custom_data)
      record
    end

    def job_started!
      record.update!(state: :started, started_at: Time.current)
      record
    end

    def prepare_record_on_enqueue(job)
      @record = ::ActiveJobStore::Record.find_or_create_by!(record_reference(job)) do |record|
        record.arguments = job.arguments
        record.details = job.as_json.except(*IGNORE_ATTRS)
        record.state = :initialized
      end
    end

    def prepare_record_on_perform(job)
      @record = ::ActiveJobStore::Record.find_or_initialize_by(record_reference(job)) do |record|
        record.arguments = job.arguments
      end
      record.details = job.as_json.except(*IGNORE_ATTRS)
      record
    end

    private

    def record_reference(job)
      {
        job_id: job.job_id,
        job_class: job.class.to_s
      }
    end
  end
end
