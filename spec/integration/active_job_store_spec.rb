# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActiveJobStore do
  let(:test_job_class) do
    Class.new(ApplicationJob) do
      include ActiveJobStore

      def perform(test_arg)
        puts test_arg

        'some result'
      end
    end
  end

  before do
    stub_const('TestJob', test_job_class)
  end

  context 'when using perform_now', freeze_time: '2022-10-14 12:34:56' do
    let(:perform_now) { TestJob.perform_now(123) }

    it 'creates an ActiveJobStore::Record with state completed', :aggregate_failures do
      expect { perform_now }.to output("123\n").to_stdout.and change(ActiveJobStore::Record, :count).by(1)

      expected_attributes = {
        job_class: 'TestJob',
        state: 'completed',
        arguments: [123],
        custom_data: nil,
        result: 'some result',
        started_at: Time.current,
        completed_at: Time.current
      }
      expect(ActiveJobStore::Record.last).to have_attributes(expected_attributes)
    end
  end

  context 'when using perform_later', freeze_time: '2022-10-14 12:34:56' do
    let(:perform_later) { TestJob.perform_later('some arg') }

    it 'creates an ActiveJobStore::Record with state enqueued', :aggregate_failures do
      expect { perform_later }.to change(ActiveJobStore::Record, :count).by(1)

      expected_attributes = {
        job_class: 'TestJob',
        state: 'enqueued',
        arguments: ['some arg'],
        enqueued_at: Time.current
      }
      expect(ActiveJobStore::Record.last).to have_attributes(expected_attributes)
    end
  end

  context 'when using wait and perform_later', freeze_time: '2022-10-14 12:34:56' do
    let(:perform_later) { TestJob.set(wait: 1.minute).perform_later(true) }

    it 'creates an ActiveJobStore::Record with state enqueued', :aggregate_failures do
      expect { perform_later }.to change(ActiveJobStore::Record, :count).by(1)

      expected_attributes = {
        job_class: 'TestJob',
        state: 'enqueued',
        arguments: [true],
        enqueued_at: Time.current
      }
      expect(ActiveJobStore::Record.last).to have_attributes(expected_attributes)
    end
  end

  context 'when the result is processed' do
    let(:perform_now) { TestJob.perform_now(456) }
    let(:test_job_class) do
      Class.new(ApplicationJob) do
        include ActiveJobStore

        def perform(test_arg)
          puts test_arg

          'some result'
        end

        def active_job_store_format_result(result)
          result.upcase
        end
      end
    end

    it 'stores the processed result in the ActiveJobStore Record', :aggregate_failures do
      expect { perform_now }.to output("456\n").to_stdout.and change(ActiveJobStore::Record, :count).by(1)

      expected_attributes = {
        job_class: 'TestJob',
        state: 'completed',
        arguments: [456],
        result: 'SOME RESULT'
      }
      expect(ActiveJobStore::Record.last).to have_attributes(expected_attributes)
    end
  end

  context 'when active_job_store_custom_data is used' do
    let(:perform_now) { TestJob.perform_now(789) }
    let(:test_job_class) do
      Class.new(ApplicationJob) do
        include ActiveJobStore

        def perform(test_arg)
          puts test_arg
          self.active_job_store_custom_data = {
            first_key: 'a value',
            second_key: 1234,
            third_key: false
          }

          'some result'
        end
      end
    end

    it 'stores the custom data in the ActiveJobStore Record', :aggregate_failures do
      expect { perform_now }.to output("789\n").to_stdout.and change(ActiveJobStore::Record, :count).by(1)

      expected_attributes = {
        job_class: 'TestJob',
        state: 'completed',
        arguments: [789],
        custom_data: {
          'first_key' => 'a value',
          'second_key' => 1234,
          'third_key' => false
        }
      }
      expect(ActiveJobStore::Record.last).to have_attributes(expected_attributes)
    end
  end

  context 'when an exception is raised during the job execution' do
    let(:perform_now) { TestJob.perform_now(111) }
    let(:test_job_class) do
      Class.new(ApplicationJob) do
        include ActiveJobStore

        def perform(test_arg) # rubocop:disable Lint/UnusedMethodArgument
          self.active_job_store_custom_data = []

          active_job_store_custom_data << 'step-1'
          raise 'Some exception'

          active_job_store_custom_data << 'step-2' # rubocop:disable Lint/UnreachableCode

          'some result'
        end
      end
    end

    it 'stores the exception message in the ActiveJobStore Record', :aggregate_failures do
      expect { perform_now }.to raise_exception('Some exception').and change(ActiveJobStore::Record, :count).by(1)

      expected_attributes = {
        job_class: 'TestJob',
        state: 'error',
        arguments: [111],
        custom_data: ['step-1'],
        exception: '#<RuntimeError: Some exception>'
      }
      expect(ActiveJobStore::Record.last).to have_attributes(expected_attributes)
    end
  end
end
