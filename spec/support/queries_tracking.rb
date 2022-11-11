# frozen_string_literal: true

RSpec.shared_context 'with queries tracking' do
  def enable_queries_tracking
    ActiveSupport::Notifications.subscribe('sql.active_record') do |_name, _start, _finish, _id, payload|
      next if %w[SCHEMA TRANSACTION].include?(payload[:name])

      values = payload[:binds].map(&:value)
      yield(sql: payload[:sql], values: values)
    end
  end
end
