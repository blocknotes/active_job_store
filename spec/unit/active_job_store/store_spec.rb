# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActiveJobStore::Store do
  describe '#job_competed!' do
    subject(:job_competed!) { store.job_competed!(result: result, custom_data: custom_data) }

    let(:custom_data) { { key1: 'value1', key2: 'value2' } }
    let(:result) { 'some result' }
    let(:store) { described_class.new }
    let(:record) { instance_double(ActiveJobStore::Record, update!: nil) }

    before { allow(store).to receive(:record).and_return(record) }

    it 'updates the store record with completed state', :freeze_time do
      job_competed!
      expected_attributes = {
        state: :completed,
        completed_at: Time.current,
        result: 'some result',
        custom_data: { key1: 'value1', key2: 'value2' }
      }
      expect(record).to have_received(:update!).with(expected_attributes)
    end
  end

  describe '#job_enqueued!' do
    subject(:job_enqueued!) { store.job_enqueued! { 'enqueuing...' } }

    let(:store) { described_class.new }
    let(:record) { instance_double(ActiveJobStore::Record, lock!: nil, update!: nil) }

    before { allow(store).to receive(:record).and_return(record) }

    it 'updates the store record with enqueued state', :freeze_time do
      job_enqueued!
      expect(record).to have_received(:update!).with(state: :enqueued, enqueued_at: Time.current)
    end
  end

  describe '#job_failed!' do
    subject(:job_failed!) { store.job_failed!(exception: exception, custom_data: custom_data) }

    let(:custom_data) { { key1: 'value1', key2: 'value2' } }
    let(:exception) { instance_double(StandardError, inspect: 'some error') }
    let(:store) { described_class.new }
    let(:record) { instance_double(ActiveJobStore::Record, update!: nil) }

    before { allow(store).to receive(:record).and_return(record) }

    it 'updates the store record with error state', :freeze_time do
      job_failed!
      expected_attributes = { state: :error, exception: 'some error', custom_data: { key1: 'value1', key2: 'value2' } }
      expect(record).to have_received(:update!).with(expected_attributes)
    end
  end

  describe '#job_started!' do
    subject(:job_started!) { store.job_started! }

    let(:store) { described_class.new }
    let(:record) { instance_double(ActiveJobStore::Record, update!: nil) }

    before { allow(store).to receive(:record).and_return(record) }

    it 'updates the store record with started state', :freeze_time do
      job_started!
      expect(record).to have_received(:update!).with(state: :started, started_at: Time.current)
    end
  end

  describe '#prepare_record_on_enqueue' do
    subject(:prepare_record_on_enqueue) { described_class.new.prepare_record_on_enqueue(job) }

    let(:job) { double('SomeJob', job_id: 'some-id', arguments: [123]) } # rubocop:disable RSpec/VerifiedDoubles

    before { allow(ActiveJobStore::Record).to receive(:find_or_create_by!) }

    it 'prepares the record to store the job state' do
      prepare_record_on_enqueue
      expected_attributes = { job_class: a_kind_of(String), job_id: 'some-id' }
      expect(ActiveJobStore::Record).to have_received(:find_or_create_by!).with(expected_attributes)
    end
  end

  describe '#prepare_record_on_perform' do
    subject(:prepare_record_on_perform) { described_class.new.prepare_record_on_perform(job) }

    let(:job) do
      double('SomeJob', job_id: 'some-id', arguments: [123], exception_executions: nil, executions: nil, priority: nil, queue_name: nil, scheduled_at: nil, timezone: nil) # rubocop:disable RSpec/VerifiedDoubles
    end
    let(:record) { instance_double(ActiveJobStore::Record, 'details=' => nil) }

    before { allow(ActiveJobStore::Record).to receive(:find_or_initialize_by).and_return(record) }

    it 'prepares the record to store the job state' do
      prepare_record_on_perform
      expected_attributes = { job_class: a_kind_of(String), job_id: 'some-id' }
      expect(ActiveJobStore::Record).to have_received(:find_or_initialize_by).with(expected_attributes)
    end
  end
end
