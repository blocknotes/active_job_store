# frozen_string_literal: true

module ActiveJobStore
  class Store
    DETAILS_ATTRS = %w[exception_executions executions priority queue_name scheduled_at timezone].freeze

    attr_reader :record

    def around_enqueue(job)
      prepare_record_on_enqueue(job)
      lock_record!
      result = yield
      job_enqueued!
      job.active_job_store_internal_error('ActiveJobStore::Store around_enqueue', internal_error) if internal_error
      result
    end

    def around_perform(job)
      prepare_record_on_perform(job)
      job_started!
      result = yield
      formatted_result = job.active_job_store_format_result(result)
      job_competed!(custom_data: job.active_job_store_custom_data, result: formatted_result)
      job.active_job_store_internal_error('ActiveJobStore::Store around_perform', internal_error) if internal_error
      result
    rescue StandardError => e
      job_failed!(exception: e, custom_data: job.active_job_store_custom_data)
      raise
    end

    def update_job_custom_data(custom_data)
      wrap_errors do
        record.update!(custom_data: custom_data)
      end
    end

    private

    attr_accessor :internal_error

    def job_competed!(result:, custom_data:)
      wrap_errors do
        record.update!(state: :completed, completed_at: Time.current, result: result, custom_data: custom_data)
      end
    end

    def job_enqueued!
      wrap_errors do
        record.update!(state: :enqueued, enqueued_at: Time.current)
      end
    end

    def job_failed!(exception:, custom_data:)
      wrap_errors do
        record.update!(state: :error, exception: exception.inspect, custom_data: custom_data)
      end
    end

    def job_started!
      wrap_errors do
        record.update!(state: :started, started_at: Time.current)
      end
    end

    def lock_record!
      wrap_errors do
        record.lock! # NOTE: needed to avoid update conflicts with perform when setting the state to enqueued
      end
    end

    def prepare_record_on_enqueue(job)
      wrap_errors do
        @record = ::ActiveJobStore::Record.find_or_create_by!(record_reference(job)) do |record|
          record.arguments = job.arguments
          record.details = DETAILS_ATTRS.zip(DETAILS_ATTRS.map { job.send(_1) }).to_h
          record.state = :initialized
        end
      end
    end

    def prepare_record_on_perform(job)
      wrap_errors do
        @record = ::ActiveJobStore::Record.find_or_initialize_by(record_reference(job)) do |record|
          record.arguments = job.arguments
        end
        record.details = DETAILS_ATTRS.zip(DETAILS_ATTRS.map { job.send(_1) }).to_h
        record
      end
    end

    def record_reference(job)
      {
        job_id: job.job_id,
        job_class: job.class.to_s
      }
    end

    def wrap_errors
      return if internal_error

      yield
    rescue StandardError => e
      self.internal_error = e
    end
  end
end
