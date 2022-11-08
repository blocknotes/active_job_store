# frozen_string_literal: true

RSpec.configure do |config|
  config.include ActiveSupport::Testing::TimeHelpers

  config.around(:example, :freeze_time) do |example|
    time = example.metadata[:freeze_time].in_time_zone rescue Time.current # rubocop:disable Style/RescueModifier
    travel_to time
    example.run
    travel_back
  end
end
