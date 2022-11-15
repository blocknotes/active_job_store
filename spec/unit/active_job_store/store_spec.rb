# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActiveJobStore::Store do
  describe '#around_enqueue' do
    subject(:around_enqueue) do
      described_class.new.around_enqueue(job) { puts 'in the queue' }
    end

    let(:job) { double('SomeJob', job_id: 'some-id', arguments: [123]) } # rubocop:disable RSpec/VerifiedDoubles
    let(:record) { instance_double(ActiveJobStore::Record, lock!: nil, update!: nil) }

    before { allow(ActiveJobStore::Record).to receive(:find_or_create_by!).and_return(record) }

    it 'creates a new ActiveJobStore::Record record and updates its state to enqueued', :aggregate_failures, :freeze_time do
      expect { around_enqueue }.to output("in the queue\n").to_stdout
      expected_attributes = { job_class: a_kind_of(String), job_id: 'some-id' }
      expect(ActiveJobStore::Record).to have_received(:find_or_create_by!).with(expected_attributes)
      expect(record).to have_received(:update!).with(state: :enqueued, enqueued_at: Time.current)
    end
  end

  describe '#around_perform' do
    subject(:around_perform) do
      described_class.new.around_perform(job) { puts 'performing' }
    end

    let(:job) do
      # rubocop:disable RSpec/VerifiedDoubles
      double('SomeJob', job_id: 'some-id', arguments: [123], executions: nil, exception_executions: nil, priority: nil, queue_name: nil, scheduled_at: nil, timezone: nil, active_job_store_format_result: nil, active_job_store_custom_data: nil)
      # rubocop:enable RSpec/VerifiedDoubles
    end
    let(:record) { instance_double(ActiveJobStore::Record, 'details=': nil, update!: nil) }

    before { allow(ActiveJobStore::Record).to receive(:find_or_initialize_by).and_return(record) }

    it 'creates a new ActiveJobStore::Record record and updates its state', :aggregate_failures, :freeze_time do
      expect { around_perform }.to output("performing\n").to_stdout
      expect(record).to have_received(:update!).with(state: :started, started_at: Time.current).ordered
      expect(record).to have_received(:update!).with(state: :completed, completed_at: Time.current, custom_data: nil, result: nil).ordered
    end
  end

  describe '#update_job_custom_data' do
    subject(:update_job_custom_data) { store.update_job_custom_data(some: 'data') }

    let(:store) { described_class.new }
    let(:record) { instance_double(ActiveJobStore::Record, update!: nil) }

    before { allow(store).to receive(:record).and_return(record) }

    it 'updates the custom data on the record' do
      update_job_custom_data
      expect(record).to have_received(:update!).with(custom_data: { some: 'data' })
    end
  end
end
