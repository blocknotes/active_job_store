# frozen_string_literal: true

begin
  require 'bundler/setup'
rescue LoadError
  puts 'You must `gem install bundler` and `bundle install` to run rake tasks'
end

require 'rdoc/task'

RDoc::Task.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'ActiveJobStore'
  rdoc.options << '--line-numbers'
  rdoc.rdoc_files.include('README.md')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

app_ver = ENV.fetch('RAILS', '7.0').tr('.', '')
APP_RAKEFILE = File.expand_path("spec/dummy#{app_ver}/Rakefile", __dir__)
load 'rails/tasks/engine.rake'

load 'rails/tasks/statistics.rake'

require 'bundler/gem_tasks'

begin
  require 'rspec/core/rake_task'

  RSpec::Core::RakeTask.new(:spec) do |t|
    # t.ruby_opts = %w[-w]
    t.rspec_opts = ['--color', '--format documentation']
  end

  task default: :spec
rescue LoadError
  puts '! LoadError: no RSpec available'
end
