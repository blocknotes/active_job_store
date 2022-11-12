# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActiveJobStore do
  include_context 'with queries tracking'

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

  context 'when using perform_now', :freeze_time do
    let(:perform_now) { TestJob.perform_now(123) }

    it 'creates an ActiveJobStore::Record with state completed', :aggregate_failures do
      expect { perform_now }.to output("123\n").to_stdout.and change(ActiveJobStore::Record, :count).by(1)

      expected_details = a_hash_including(
        'executions' => 1,
        'queue_name' => 'default'
      )
      expected_attributes = {
        job_class: 'TestJob',
        state: 'completed',
        arguments: [123],
        custom_data: nil,
        details: expected_details,
        result: 'some result',
        started_at: Time.current,
        completed_at: Time.current
      }
      expect(ActiveJobStore::Record.last).to have_attributes(expected_attributes)
    end

    it 'executes only the expected queries', :aggregate_failures do
      queries = []
      enable_queries_tracking { |query| queries << query }
      expect { perform_now }.to output("123\n").to_stdout

      expected_queries = [
        'SELECT "active_job_store".* FROM "active_job_store" WHERE "active_job_store"."job_id" = ? AND "active_job_store"."job_class" = ? LIMIT ?',
        'INSERT INTO "active_job_store" ("job_id", "job_class", "state", "arguments", "custom_data", "details", "result", "exception", "enqueued_at", "started_at", "completed_at", "created_at") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        'UPDATE "active_job_store" SET "state" = ?, "result" = ?, "completed_at" = ? WHERE "active_job_store"."id" = ?'
      ]
      expect(queries.pluck(:sql)).to match_array(expected_queries)

      details = { 'exception_executions' => {}, 'executions' => 1, 'priority' => nil, 'queue_name' => 'default', 'scheduled_at' => nil, 'timezone' => 'UTC' }
      expected_insert_values = [a_kind_of(String), 'TestJob', 'started', [123], nil, details, nil, nil, nil, Time.current, nil, Time.current]
      expect(queries[1]).to include(values: expected_insert_values)

      expected_update_values = ['completed', 'some result', Time.current, 1]
      expect(queries[2]).to include(values: expected_update_values)
    end
  end

  context 'when using perform_later', :freeze_time do
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

    it 'executes only the expected queries', :aggregate_failures do
      queries = []
      enable_queries_tracking { |query| queries << query }
      perform_later

      expected_queries = [
        'SELECT "active_job_store".* FROM "active_job_store" WHERE "active_job_store"."job_id" = ? AND "active_job_store"."job_class" = ? LIMIT ?',
        'INSERT INTO "active_job_store" ("job_id", "job_class", "state", "arguments", "custom_data", "details", "result", "exception", "enqueued_at", "started_at", "completed_at", "created_at") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        'SELECT "active_job_store".* FROM "active_job_store" WHERE "active_job_store"."id" = ? LIMIT ?',
        'UPDATE "active_job_store" SET "state" = ?, "enqueued_at" = ? WHERE "active_job_store"."id" = ?'
      ]
      expect(queries.pluck(:sql).map(&:strip)).to match_array(expected_queries)

      details = { 'exception_executions' => {}, 'executions' => 0, 'priority' => nil, 'queue_name' => 'default', 'scheduled_at' => nil, 'timezone' => 'UTC' }
      expected_insert_values = [a_kind_of(String), 'TestJob', 'initialized', ['some arg'], nil, details, nil, nil, nil, nil, nil, Time.current]
      expect(queries[1]).to include(values: expected_insert_values)

      expected_update_values = ['enqueued', Time.current, 1]
      expect(queries[3]).to include(values: expected_update_values)
    end
  end

  context 'when using wait and perform_later', :freeze_time do
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

    it 'executes only the expected queries', :aggregate_failures do
      queries = []
      enable_queries_tracking { |query| queries << query }
      perform_later

      expected_queries = [
        'SELECT "active_job_store".* FROM "active_job_store" WHERE "active_job_store"."job_id" = ? AND "active_job_store"."job_class" = ? LIMIT ?',
        'INSERT INTO "active_job_store" ("job_id", "job_class", "state", "arguments", "custom_data", "details", "result", "exception", "enqueued_at", "started_at", "completed_at", "created_at") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        'SELECT "active_job_store".* FROM "active_job_store" WHERE "active_job_store"."id" = ? LIMIT ?',
        'UPDATE "active_job_store" SET "state" = ?, "enqueued_at" = ? WHERE "active_job_store"."id" = ?'
      ]
      expect(queries.pluck(:sql).map(&:strip)).to match_array(expected_queries)

      details = { 'exception_executions' => {}, 'executions' => 0, 'priority' => nil, 'queue_name' => 'default', 'scheduled_at' => a_kind_of(Float), 'timezone' => 'UTC' }
      expected_insert_values = [a_kind_of(String), 'TestJob', 'initialized', [true], nil, details, nil, nil, nil, nil, nil, Time.current]
      expect(queries[1]).to include(values: expected_insert_values)

      expected_update_values = ['enqueued', Time.current, 1]
      expect(queries[3]).to include(values: expected_update_values)
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

  context 'when updating custom data during the perform' do
    let(:perform_now) { TestJob.perform_now(111) }
    let(:test_job_class) do
      Class.new(ApplicationJob) do
        include ActiveJobStore

        def perform(test_arg) # rubocop:disable Lint/UnusedMethodArgument
          save_job_custom_data(progress: 0.5)
          # do something else ...
          save_job_custom_data(progress: 1.0)

          'some result'
        end
      end
    end

    it 'executes only the expected queries', :aggregate_failures, :freeze_time do
      queries = []
      enable_queries_tracking { |query| queries << query }
      perform_now

      expected_queries = [
        'SELECT "active_job_store".* FROM "active_job_store" WHERE "active_job_store"."job_id" = ? AND "active_job_store"."job_class" = ? LIMIT ?',
        'INSERT INTO "active_job_store" ("job_id", "job_class", "state", "arguments", "custom_data", "details", "result", "exception", "enqueued_at", "started_at", "completed_at", "created_at") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        'UPDATE "active_job_store" SET "custom_data" = ? WHERE "active_job_store"."id" = ?',
        'UPDATE "active_job_store" SET "custom_data" = ? WHERE "active_job_store"."id" = ?',
        'UPDATE "active_job_store" SET "state" = ?, "result" = ?, "completed_at" = ? WHERE "active_job_store"."id" = ?'
      ]
      expect(queries.pluck(:sql)).to match_array(expected_queries)

      details = { 'exception_executions' => {}, 'executions' => 1, 'priority' => nil, 'queue_name' => 'default', 'scheduled_at' => nil, 'timezone' => 'UTC' }
      expected_insert_values = [a_kind_of(String), 'TestJob', 'started', [111], nil, details, nil, nil, nil, Time.current, nil, Time.current]
      expect(queries[1]).to include(values: expected_insert_values)
      expect(queries[2]).to include(values: [{ 'progress' => 0.5 }, 1])
      expect(queries[3]).to include(values: [{ 'progress' => 1.0 }, 1])
      expect(queries[4]).to include(values: ['completed', 'some result', Time.current, 1])
    end

    context 'with a stubbed record' do
      let(:record) { instance_double(ActiveJobStore::Record, 'details=': nil, update!: nil) }

      before do
        allow(ActiveJobStore::Record).to receive(:find_or_initialize_by).and_return(record)
      end

      it 'stores custom data in the ActiveJobStore Record', :aggregate_failures, :freeze_time do
        perform_now

        expect(record).to have_received(:update!).with(started_at: Time.current, state: :started).ordered
        expect(record).to have_received(:update!).with(custom_data: { progress: 0.5 }).ordered
        expect(record).to have_received(:update!).with(custom_data: { progress: 1.0 }).ordered

        expected_attributes = {
          completed_at: Time.current,
          custom_data: { progress: 1.0 },
          result: 'some result',
          state: :completed
        }
        expect(record).to have_received(:update!).with(expected_attributes).ordered
      end
    end
  end
end
