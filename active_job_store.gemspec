# frozen_string_literal: true

$:.push File.expand_path('lib', __dir__)

require 'active_job_store/version'

Gem::Specification.new do |spec|
  spec.platform    = Gem::Platform::RUBY
  spec.name        = 'active_job_store'
  spec.version     = ActiveJobStore::VERSION
  spec.summary     = 'Persist jobs information on DB'
  spec.description = 'ActiveJob Store permits to store jobs state and custom data on a database'
  spec.license     = 'MIT'

  spec.required_ruby_version = '>= 2.6.0'

  spec.author   = 'Mattia Roccoberton'
  spec.email    = 'mat@blocknot.es'
  spec.homepage = 'https://github.com/blocknotes/active_job_store'

  spec.metadata = {
    'homepage_uri' => spec.homepage,
    'source_code_uri' => spec.homepage,
    'changelog_uri' => 'https://github.com/blocknotes/active_job_store/blob/master/CHANGELOG.md',
    'rubygems_mfa_required' => 'true'
  }

  spec.files         = Dir['{app,db,lib}/**/*', 'LICENSE.txt', 'README.md']
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'activejob', '>= 6.0'
  spec.add_runtime_dependency 'activerecord', '>= 6.0'
end
