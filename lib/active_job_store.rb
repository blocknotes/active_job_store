# frozen_string_literal: true

require_relative 'active_job_store/engine'
require_relative 'active_job_store/store'

module ActiveJobStore
  # Set / manipulate job's custom data
  attr_accessor :active_job_store_custom_data

  # Format / manipulate / serialize the job result
  #
  # @param result [any] Job's return value
  #
  # @return [any] Processed job's return value
  def active_job_store_format_result(result)
    result
  end

  # Persist custom data while the job is performing
  #
  # @param custom_data [any] Attributes to serialize (it must be serializable in JSON)
  def save_job_custom_data(custom_data = nil)
    self.active_job_store_custom_data = custom_data if custom_data
    store.update_job_custom_data(active_job_store_custom_data)
  end

  # Return the associated Active Job Store record
  #
  # @return [ActiveJobStore::Record] the corresponding record
  def active_job_store_record
    store.record
  end

  module ClassMethods
    # Query the list of job executions for the current job class
    #
    # @return [ActiveRecord Relation] query result
    def job_executions
      ::ActiveJobStore::Record.where(job_class: to_s)
    end
  end

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

  private

  def store
    @store ||= ::ActiveJobStore::Store.new
  end
end
