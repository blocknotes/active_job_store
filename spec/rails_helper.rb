# frozen_string_literal: true

require 'spec_helper'
ENV['RAILS_ENV'] = 'test'

require 'simplecov'
SimpleCov.start 'rails'

app_ver = ENV.fetch('RAILS', '7.0').tr('.', '')
require File.expand_path("dummy#{app_ver}/config/environment.rb", __dir__)

abort('The Rails environment is running in production mode!') if Rails.env.production?

require 'rspec/rails'
require 'super_diff/rspec-rails'

Dir[File.expand_path('support/**/*.rb', __dir__)].sort.each { |f| require f }

# Force deprecations to raise an exception.
# ActiveSupport::Deprecation.behavior = :raise

# Checks for pending migrations and applies them before tests are run.
# If you are not using ActiveRecord, you can remove these lines.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  puts e.to_s.strip
  exit 1
end

module RSpecUtils
  module_function

  def rails70?
    Gem::Version.new(Rails.version) >= Gem::Version.new('7.0')
  end

  def rails71?
    Gem::Version.new(Rails.version) >= Gem::Version.new('7.1')
  end
end

RSpec.configure do |config|
  config.fixture_path = "#{::Rails.root}/spec/fixtures"
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.use_transactional_fixtures = true
  config.use_instantiated_fixtures = false
  config.render_views = false

  config.before(:suite) do
    intro = ('-' * 80)
    intro << "\n"
    intro << "- Ruby:        #{RUBY_VERSION}\n"
    intro << "- Rails:       #{Rails.version}\n"
    intro << ('-' * 80)

    RSpec.configuration.reporter.message(intro)
  end
end
