# frozen_string_literal: true

class SomeJob < ApplicationJob
  include ActiveJobStore

  def perform(some_id)
    self.active_job_store_custom_data = []

    active_job_store_custom_data << { time: Time.current, message: 'SomeJob step 1' }
    save_job_custom_data

    Rails.logger.debug { "> SomeJob is performing with #{some_id}" }
    sleep 3
    active_job_store_custom_data << { time: Time.current, message: 'SomeJob step 2' }
    save_job_custom_data

    'some_result'
  end
end
