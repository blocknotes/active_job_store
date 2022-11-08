# frozen_string_literal: true

class AnotherJob < ApplicationJob
  include ActiveJobStore

  def perform(some_id)
    Rails.logger.debug { "> AnotherJob is performing with #{some_id}" }

    42
  end

  def active_job_store_format_result(result)
    result * 2
  end
end
