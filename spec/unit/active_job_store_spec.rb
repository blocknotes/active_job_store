# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActiveJobStore do
  let(:test_job_class) do
    Class.new(ApplicationJob) do
      include ActiveJobStore

      def perform(test_arg)
        puts test_arg
      end
    end
  end

  before do
    stub_const('TestJob', test_job_class)
  end

  describe '.job_executions' do
    subject(:job_executions) { TestJob.job_executions }

    before { allow(ActiveJobStore::Record).to receive(:where) }

    it 'filters the ActiveJobStore::Record entities by job class' do
      job_executions
      expect(ActiveJobStore::Record).to have_received(:where).with(job_class: 'TestJob')
    end
  end

  describe '#active_job_store_reference' do
    subject(:active_job_store_reference) { TestJob.new.active_job_store_reference }

    it 'returns the job reference attributes' do
      expect(active_job_store_reference).to match(
        job_class: 'TestJob',
        job_id: a_kind_of(String)
      )
    end
  end

  describe '#active_job_store_format_result' do
    subject(:active_job_store_format_result) { TestJob.new.active_job_store_format_result(123) }

    it 'returns the argument' do
      expect(active_job_store_format_result).to eq 123
    end
  end
end
