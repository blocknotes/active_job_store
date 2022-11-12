# frozen_string_literal: true

class AnotherJob < ApplicationJob
  include ActiveJobStore

  def perform(some_id)
    save_job_custom_data(progress: 0.0)
    Rails.logger.debug { "> AnotherJob is performing with #{some_id} - Step 1" }
    sleep 2
    save_job_custom_data(progress: 0.5)
    Rails.logger.debug { "> AnotherJob is performing with #{some_id} - Step 2" }
    sleep 2
    save_job_custom_data(progress: 1.0)

    42
  end

  def active_job_store_format_result(result)
    result * 2
  end
end
