# frozen_string_literal: true

require_relative 'active_job_store/engine'
require_relative 'active_job_store/store'

module ActiveJobStore
  attr_accessor :active_job_store_custom_data

  class << self
    def included(base)
      base.extend(ClassMethods)

      base.around_enqueue do |job, block|
        store.prepare_record_on_enqueue(job)
        store.job_enqueued! do
          block.call
        end
      end

      base.around_perform do |job, block|
        store.prepare_record_on_perform(job)
        store.job_started!
        result = block.call
        formatted_result = job.active_job_store_format_result(result)
        store.job_competed!(custom_data: active_job_store_custom_data, result: formatted_result)
      rescue StandardError => e
        store.job_failed!(exception: e, custom_data: active_job_store_custom_data)
        raise
      end
    end
  end

  def active_job_store_format_result(result)
    result
  end

  module ClassMethods
    def job_executions
      ::ActiveJobStore::Record.where(job_class: to_s)
    end
  end

  private

  def store
    @store ||= ::ActiveJobStore::Store.new
  end
end
