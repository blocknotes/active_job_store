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

      insert_query =
        if RSpecUtils.rails71?
          'INSERT INTO "active_job_store" ("job_id", "job_class", "state", "arguments", "custom_data", "details", "result", "exception", "enqueued_at", "started_at", "completed_at", "created_at") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) RETURNING "id"'
        elsif RSpecUtils.rails70?
          'INSERT INTO "active_job_store" ("job_id", "job_class", "state", "arguments", "custom_data", "details", "result", "exception", "enqueued_at", "started_at", "completed_at", "created_at") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
        else
          'INSERT INTO "active_job_store" ("job_id", "job_class", "state", "arguments", "details", "started_at", "created_at") VALUES (?, ?, ?, ?, ?, ?, ?)'
        end

      expected_queries = [
        'SELECT "active_job_store".* FROM "active_job_store" WHERE "active_job_store"."job_id" = ? AND "active_job_store"."job_class" = ? LIMIT ?',
        insert_query,
        'UPDATE "active_job_store" SET "state" = ?, "result" = ?, "completed_at" = ? WHERE "active_job_store"."id" = ?'
      ]
      expect(queries.pluck(:sql)).to match_array(expected_queries)

      details = { 'exception_executions' => {}, 'executions' => 1, 'priority' => nil, 'queue_name' => 'default', 'scheduled_at' => nil, 'timezone' => 'UTC' }
      expected_insert_values = [a_kind_of(String), 'TestJob', 'started', [123], details, Time.current, Time.current]
      expect(queries.dig(1, :values).compact).to match(expected_insert_values)

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

      insert_query =
        if RSpecUtils.rails71?
          'INSERT INTO "active_job_store" ("job_id", "job_class", "state", "arguments", "custom_data", "details", "result", "exception", "enqueued_at", "started_at", "completed_at", "created_at") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) RETURNING "id"'
        elsif RSpecUtils.rails70?
          'INSERT INTO "active_job_store" ("job_id", "job_class", "state", "arguments", "custom_data", "details", "result", "exception", "enqueued_at", "started_at", "completed_at", "created_at") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
        else
          'INSERT INTO "active_job_store" ("job_id", "job_class", "state", "arguments", "details", "created_at") VALUES (?, ?, ?, ?, ?, ?)'
        end
      expected_queries = [
        'SELECT "active_job_store".* FROM "active_job_store" WHERE "active_job_store"."job_id" = ? AND "active_job_store"."job_class" = ? LIMIT ?',
        insert_query,
        'SELECT "active_job_store".* FROM "active_job_store" WHERE "active_job_store"."id" = ? LIMIT ?',
        'UPDATE "active_job_store" SET "state" = ?, "enqueued_at" = ? WHERE "active_job_store"."id" = ?'
      ]
      expect(queries.pluck(:sql).map(&:strip)).to match_array(expected_queries)

      details = { 'exception_executions' => {}, 'executions' => 0, 'priority' => nil, 'queue_name' => 'default', 'scheduled_at' => nil, 'timezone' => 'UTC' }
      expected_insert_values = [a_kind_of(String), 'TestJob', 'initialized', ['some arg'], details, Time.current]
      expect(queries.dig(1, :values).compact).to match(expected_insert_values)

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

      insert_query =
        if RSpecUtils.rails71?
          'INSERT INTO "active_job_store" ("job_id", "job_class", "state", "arguments", "custom_data", "details", "result", "exception", "enqueued_at", "started_at", "completed_at", "created_at") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) RETURNING "id"'
        elsif RSpecUtils.rails70?
          'INSERT INTO "active_job_store" ("job_id", "job_class", "state", "arguments", "custom_data", "details", "result", "exception", "enqueued_at", "started_at", "completed_at", "created_at") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
        else
          'INSERT INTO "active_job_store" ("job_id", "job_class", "state", "arguments", "details", "created_at") VALUES (?, ?, ?, ?, ?, ?)'
        end

      expected_queries = [
        'SELECT "active_job_store".* FROM "active_job_store" WHERE "active_job_store"."job_id" = ? AND "active_job_store"."job_class" = ? LIMIT ?',
        insert_query,
        'SELECT "active_job_store".* FROM "active_job_store" WHERE "active_job_store"."id" = ? LIMIT ?',
        'UPDATE "active_job_store" SET "state" = ?, "enqueued_at" = ? WHERE "active_job_store"."id" = ?'
      ]
      expect(queries.pluck(:sql).map(&:strip)).to match_array(expected_queries)

      scheduled_at = RSpecUtils.rails71? ? a_kind_of(String) : a_kind_of(Float)
      details = { 'exception_executions' => {}, 'executions' => 0, 'priority' => nil, 'queue_name' => 'default', 'scheduled_at' => scheduled_at, 'timezone' => 'UTC' }
      expected_insert_values = [a_kind_of(String), 'TestJob', 'initialized', [true], details, Time.current]
      expect(queries.dig(1, :values).compact).to match(expected_insert_values)

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

      custom_data = {
        'first_key' => 'a value',
        'second_key' => 1234,
        'third_key' => false
      }
      custom_data.symbolize_keys! unless RSpecUtils.rails71?
      expected_attributes = {
        job_class: 'TestJob',
        state: 'completed',
        arguments: [789],
        custom_data: custom_data
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

      insert_query =
        if RSpecUtils.rails71?
          'INSERT INTO "active_job_store" ("job_id", "job_class", "state", "arguments", "custom_data", "details", "result", "exception", "enqueued_at", "started_at", "completed_at", "created_at") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) RETURNING "id"'
        elsif RSpecUtils.rails70?
          'INSERT INTO "active_job_store" ("job_id", "job_class", "state", "arguments", "custom_data", "details", "result", "exception", "enqueued_at", "started_at", "completed_at", "created_at") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
        else
          'INSERT INTO "active_job_store" ("job_id", "job_class", "state", "arguments", "details", "started_at", "created_at") VALUES (?, ?, ?, ?, ?, ?, ?)'
        end

      expected_queries = [
        'SELECT "active_job_store".* FROM "active_job_store" WHERE "active_job_store"."job_id" = ? AND "active_job_store"."job_class" = ? LIMIT ?',
        insert_query,
        'UPDATE "active_job_store" SET "custom_data" = ? WHERE "active_job_store"."id" = ?',
        'UPDATE "active_job_store" SET "custom_data" = ? WHERE "active_job_store"."id" = ?',
        'UPDATE "active_job_store" SET "state" = ?, "result" = ?, "completed_at" = ? WHERE "active_job_store"."id" = ?'
      ]
      expect(queries.pluck(:sql)).to match_array(expected_queries)

      details = { 'exception_executions' => {}, 'executions' => 1, 'priority' => nil, 'queue_name' => 'default', 'scheduled_at' => nil, 'timezone' => 'UTC' }
      expected_insert_values = [a_kind_of(String), 'TestJob', 'started', [111], details, Time.current, Time.current]
      expect(queries.dig(1, :values).compact).to match(expected_insert_values)
      expect(queries[4]).to include(values: ['completed', 'some result', Time.current, 1])

      if RSpecUtils.rails71?
        expect(queries[2]).to include(values: [{ 'progress' => 0.5 }, 1])
        expect(queries[3]).to include(values: [{ 'progress' => 1.0 }, 1])
      else
        expect(queries[2]).to include(values: [{ progress: 0.5 }, 1])
        expect(queries[3]).to include(values: [{ progress: 1.0 }, 1])
      end
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

  context 'when querying the job executions list' do
    let(:job_executions) { TestJob.job_executions }

    it 'executes only the expected queries', :aggregate_failures do
      queries = []
      enable_queries_tracking { |query| queries << query }
      job_executions.to_a

      expected_query = {
        sql: 'SELECT "active_job_store".* FROM "active_job_store" WHERE "active_job_store"."job_class" = ?',
        values: ['TestJob']
      }
      expect(queries).to match_array([expected_query])
    end

    it 'uses the defined index when listing job executions', :aggregate_failures do
      expect { TestJob.perform_now(123) }.to output("123\n").to_stdout.and change(ActiveJobStore::Record, :count).by(1)
      expect { TestJob.perform_now(234) }.to output("234\n").to_stdout.and change(ActiveJobStore::Record, :count).by(1)
      expect { TestJob.perform_now(345) }.to output("345\n").to_stdout.and change(ActiveJobStore::Record, :count).by(1)

      expect(job_executions.explain).to include 'USING INDEX index_active_job_store_on_job_class_and_state'
      completed_jobs = TestJob.job_executions.completed
      expect(completed_jobs.explain).to include 'USING INDEX index_active_job_store_on_job_class_and_state'
    end

    it 'uses the defined index when looking for a specific job', :aggregate_failures do
      expect { TestJob.perform_now(123) }.to output("123\n").to_stdout.and change(ActiveJobStore::Record, :count).by(1)
      expect { TestJob.perform_now(234) }.to output("234\n").to_stdout.and change(ActiveJobStore::Record, :count).by(1)
      expect { TestJob.perform_now(345) }.to output("345\n").to_stdout.and change(ActiveJobStore::Record, :count).by(1)

      job_id = job_executions.first.job_id
      find_by_job = TestJob.job_executions.where(job_id: job_id).limit(1)
      expect(find_by_job.explain).to include 'USING INDEX index_active_job_store_on_job_class_and_job_id'
    end
  end

  context "when there's an internal error" do
    let(:perform_now) { TestJob.perform_now }
    let(:test_job_class) do
      Class.new(ApplicationJob) do
        include ActiveJobStore

        def perform
          'some result'
        end
      end
    end

    before do
      allow(ActiveJobStore::Record).to receive(:find_or_initialize_by).and_raise('internal error')
    end

    it 'continues to perform the job anyway' do
      expect { perform_now }.to output("ActiveJobStore::Store around_perform: internal error\n").to_stderr
      expect(perform_now).to eq 'some result'
      expect(ActiveJobStore::Record.count).to be_zero
    end
  end

  context "when a active_job_store_internal_error is defined and there's an error" do
    let(:perform_now) { TestJob.perform_now }
    let(:test_job_class) do
      Class.new(ApplicationJob) do
        include ActiveJobStore

        def perform
          'some result'
        end

        def active_job_store_internal_error(_context, exception)
          raise exception
        end
      end
    end

    before do
      allow(ActiveJobStore::Record).to receive(:find_or_initialize_by).and_raise('internal error')
    end

    it 'raises the internal error' do
      expect { perform_now }.to raise_exception('internal error')
    end
  end
end
