# ActiveJob Store

[![Gem Version](https://badge.fury.io/rb/active_job_store.svg)](https://badge.fury.io/rb/active_job_store)
[![Specs Rails 7.0](https://github.com/blocknotes/active_job_store/actions/workflows/specs_70.yml/badge.svg)](https://github.com/blocknotes/active_job_store/actions/workflows/specs_70.yml)
[![Linters](https://github.com/blocknotes/active_job_store/actions/workflows/linters.yml/badge.svg)](https://github.com/blocknotes/active_job_store/actions/workflows/linters.yml)

Persist job execution information on a support model `ActiveJobStore::Record`.

It can be useful to:
- improve jobs logging capabilities;
- query historical data about job executions;
- extract job's statistical data;
- track a job's state or add custom data to the jobs.

Support some customizations:
- set custom data attributes (via `active_job_store_custom_data` accessor);
- format the job result to store (overriding `active_job_store_format_result` method).

## Installation

- Add to your Gemfile `gem 'active_job_store'` (and execute: `bundle`)
- Copy the gem migrations: `bundle exec rails active_job_store:install:migrations`
- Apply the new migrations: `bundle exec rails db:migrate`
- Add to your job `include ActiveJobStore` (or to your `ApplicationJob` class if you prefer)
- Access to the job executions data using the class method `job_executions` on your job (ex. `YourJob.job_executions`)

## Usage examples

```rb
SomeJob.perform_now(123)
SomeJob.perform_later(456)
SomeJob.set(wait: 1.minute).perform_later(789)

SomeJob.job_executions.first
# => #<ActiveJobStore::Record:0x00000001120f6320
#  id: 1,
#  job_id: "58daef7c-6b78-4d90-8043-39116eb9fe77",
#  job_class: "SomeJob",
#  state: "completed",
#  arguments: [123],
#  custom_data: nil,
#  details: {"queue_name"=>"default", "priority"=>nil, "executions"=>1, "exception_executions"=>{}, "timezone"=>"UTC"},
#  result: "some_result",
#  exception: nil,
#  enqueued_at: nil,
#  started_at: Wed, 09 Nov 2022 21:09:50.611355000 UTC +00:00,
#  completed_at: Wed, 09 Nov 2022 21:09:50.622797000 UTC +00:00,
#  created_at: Wed, 09 Nov 2022 21:09:50.611900000 UTC +00:00>
```

Extract some logs:

```rb
puts ::ActiveJobStore::Record.order(id: :desc).pluck(:created_at, :job_class, :arguments, :state, :completed_at).map { _1.join(', ') }
# 2022-11-09 21:20:57 UTC, SomeJob, 123, completed, 2022-11-09 21:20:58 UTC
# 2022-11-09 21:18:26 UTC, AnotherJob, another test 2, completed, 2022-11-09 21:18:26 UTC
# 2022-11-09 21:13:18 UTC, SomeJob, Some test 3, completed, 2022-11-09 21:13:19 UTC
# 2022-11-09 21:12:18 UTC, SomeJob, Some test 2, error,
# 2022-11-09 21:10:13 UTC, AnotherJob, another test, completed, 2022-11-09 21:10:13 UTC
# 2022-11-09 21:09:50 UTC, SomeJob, Some test, completed, 2022-11-09 21:09:50 UTC
```

Query jobs in a specific range of time:

```rb
SomeJob.job_executions.where(started_at: 16.minutes.ago...).pluck(:job_id, :result, :started_at)
# => [["02beb3d6-a4eb-442c-8d78-29103ab894dc", "some_result", Wed, 09 Nov 2022 21:20:57.576018000 UTC +00:00],
#  ["267e087e-cfa7-4c88-8d3b-9d40f912733f", "some_result", Wed, 09 Nov 2022 21:13:18.011484000 UTC +00:00]]
```

Some statistics on completed jobs:

```rb
SomeJob.job_executions.completed.map { |job| { id: job.id, execution_time: job.completed_at - job.started_at, started_at: job.started_at } }
# => [{:id=>6, :execution_time=>1.005239, :started_at=>Wed, 09 Nov 2022 21:20:57.576018000 UTC +00:00},
#  {:id=>4, :execution_time=>1.004485, :started_at=>Wed, 09 Nov 2022 21:13:18.011484000 UTC +00:00},
#  {:id=>1, :execution_time=>0.011442, :started_at=>Wed, 09 Nov 2022 21:09:50.611355000 UTC +00:00}]
```

## Customizations

If you need to store custom data, use `active_job_store_custom_data` accessor:

```rb
class AnotherJob < ApplicationJob
  include ActiveJobStore

  def perform(some_id)
    self.active_job_store_custom_data = []

    active_job_store_custom_data << { time: Time.current, message: 'SomeJob step 1' }
    sleep 1
    active_job_store_custom_data << { time: Time.current, message: 'SomeJob step 2' }

    'some_result'
  end
end

AnotherJob.perform_now(123)
AnotherJob.job_executions.last.custom_data
# => [{"time"=>"2022-11-09T21:20:57.580Z", "message"=>"SomeJob step 1"}, {"time"=>"2022-11-09T21:20:58.581Z", "message"=>"SomeJob step 2"}]
```

If for any reason it's needed to process the result before storing it, just override `active_job_store_format_result`:

```rb
class AnotherJob < ApplicationJob
  include ActiveJobStore

  def perform(some_id)
    42
  end

  def active_job_store_format_result(result)
    result * 2
  end
end

AnotherJob.perform_now(123)
AnotherJob.job_executions.last.result
# => 84
```

## Do you like it? Star it!

If you use this component just star it. A developer is more motivated to improve a project when there is some interest.

Or consider offering me a coffee, it's a small thing but it is greatly appreciated: [about me](https://www.blocknot.es/about-me).

## Contributors

- [Mattia Roccoberton](https://blocknot.es/): author

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
