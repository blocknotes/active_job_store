# frozen_string_literal: true

class SomeJob < ApplicationJob
  include ActiveJobStore

  def perform(some_id)
    self.active_job_store_custom_data = []

    active_job_store_custom_data << { time: Time.current, message: 'SomeJob step 1' }
    Rails.logger.debug { "> SomeJob is performing with #{some_id}" }
    sleep 1
    active_job_store_custom_data << { time: Time.current, message: 'SomeJob step 2' }

    'some_result'
  end
end
