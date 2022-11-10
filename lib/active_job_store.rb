# frozen_string_literal: true

require_relative 'active_job_store/engine'

module ActiveJobStore
  IGNORE_ATTRS = %w[arguments job_id successfully_enqueued].freeze

  attr_accessor :active_job_store_custom_data

  class << self
    def included(base)
      base.extend(ClassMethods)

      base.around_enqueue do |job, block|
        store_record = ::ActiveJobStore::Record.find_or_create_by!(job.active_job_store_reference) do |record|
          record.arguments = job.arguments
          record.details = job.as_json.except(*IGNORE_ATTRS)
          record.state = :initialized
        end
        store_record.lock! # NOTE: needed to avoid update conflicts with perform when setting the state to enqueued
        block.call
        store_record.update!(state: :enqueued, enqueued_at: Time.current)
      end

      base.around_perform do |job, block|
        store_record = ::ActiveJobStore::Record.find_or_initialize_by(job.active_job_store_reference) do |record|
          record.arguments = job.arguments
        end
        store_record.update!(details: job.as_json.except(*IGNORE_ATTRS), state: :started, started_at: Time.current)
        result = block.call
        formatted_result = job.active_job_store_format_result(result)
        store_record.update!(
          state: :completed,
          completed_at: Time.current,
          result: formatted_result,
          custom_data: active_job_store_custom_data
        )
      rescue StandardError => e
        store_record.update!(state: :error, exception: e.inspect, custom_data: active_job_store_custom_data)
        raise
      end
    end
  end

  def active_job_store_format_result(result)
    result
  end

  def active_job_store_reference
    { job_id: job_id, job_class: self.class.to_s }
  end

  module ClassMethods
    def job_executions
      ::ActiveJobStore::Record.where(job_class: to_s)
    end
  end
end
