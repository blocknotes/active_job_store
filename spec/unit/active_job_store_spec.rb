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

  describe '#active_job_store_format_result' do
    subject(:active_job_store_format_result) { TestJob.new.active_job_store_format_result(123) }

    it 'returns the argument' do
      expect(active_job_store_format_result).to eq 123
    end
  end

  describe '#active_job_store_record' do
    subject(:active_job_store_record) { job.active_job_store_record }

    let(:job) { TestJob.new }
    let(:store) { instance_double(ActiveJobStore::Store, record: nil) }

    before { allow(job).to receive(:store).and_return(store) }

    it "returns the store's record" do
      active_job_store_record
      expect(store).to have_received(:record)
    end
  end
end
