resque-approve
==================

[github.com/RealNobody/resque-approve](https://github.com/RealNobody/resque-approve)

Description
-----------

This gem is based on the [Resque-Approval](https://github.com/eclubb/resque-approval) gem.

This variation of the gem is a [Resque](https://github.com/defunkt/resque)
plugin which keeps the list of jobs that are pending approval outside of Resques queues
and in its own list so that there is no cross-contamination of the Redis namespaces.

There is no assumptions of the internal workings of Resque.  This gem interfaces only
through the documented hooks and public methods of Resque to perform its work.

Installation
------------

Add the gem to your Gemfile:

```Ruby
gem "resque-approve"
```

Usage
----

###Setup

Simply include the Approve class in the class that is enqueued to Resque:

```Ruby
include Resque::Plugins::Approve
```

###Server extension

To add the server tab and views to Resqueue, add include the file
`resque/approve_server` to your `routes.rb` file.

```Ruby
require "resque/approve_server"
```

###Requiring approval for a job

Simply use any or all methods you normally would use to enqueue a job to Resque.

Jobs will run as normal without interferance.

If you want to require a job to wait for approval before being run, simply add
the following hash options to your job when it is enqueued and the job will
be delayed until it is approved.

NOTE:  When a job is actually enqueued for execution by Resque, wether initially
delayed for approval or not, the enqueued job will never include the approval
options and the job will be included as if the approval options never existed.
This will allow you to add the approval gem and the approval options to any
existing job quickly, easily and safely without additional alteration. 

Approval options:
* `approval_key` - This signals that a job is to be delayed until it is approved.
  This key is **required** in order to delay a job.  This key is used to
  approve the job to actually be enqueued.

* `approval_queue` - This is an optional parameter which will allow you to
  specify which queue the job is enqueued to.  If this is not set, the default
  queue for the class will be used as normal.

* `approval_at` - This is an optional parameter which will delay enqueue the job
  at this time when it is enqueued.

  NOTE:  This option requires the [Resque-Scheduler](https://github.com/resque/resque-scheduler)
  gem.  If you use this option and do not have the `resque-scheduler`, it will
  throw an exception.  If you do not use this option, the scheduler will not
  be used.

  If you use `enqueue_at` to enqueue a job and include approval options, then
  the job will not be available to be approved until it is actually enqueued
  at some point after the delay time.  This means that approving the job while
  it is delayed will have no effect.

  In the reverse case, if you enqueue the job and include an `approval_at`
  option, the job will not be enqueued (even delay enqueued) until it is approved.
  Once approved, it will run immediately if the current time is after the
  `approval_at` time, or be delay enqueued for that time.

####Example usage

```Ruby
class MyJob
  include Resque::Plugins::Approve

  def self.queue
    "a_queue"
  end

  def self.perform(an_arg, another_arg, options = {})
  end
end

# enqueue the job normally
Resque.equeue MyJob, "an arg", "another arg", my_options: "something"

# enqueue the job, but require approval
Resque.equeue MyJob, "an arg", "another arg", my_options: "something", approval_key: "Approve"
# Multiple jobs can be delayed for approval
Resque.equeue MyJob, "an arg 2", "another arg 2", my_options: "something", approval_key: "Approve"

# approve one job for a key
Resque::Plugins::Approve.approve_one("Approve")
# approve all jobs for a key
Resque::Plugins::Approve.approve("Approve")

# remove/reject one job for a key
Resque::Plugins::Approve.remove_one("Approve")
# remove/reject all jobs for a key
Resque::Plugins::Approve.remove("Approve")
```

Options
-------

###Job Options

When added, class methods and class instance variables are added to your job
class to configure how the Approve gem works with your class. 

```Ruby
class MyResqueJob
  include Resque::Plugins::Approve

  # Call class methods or set class instance variables to set values for options...
  self.auto_delete_approval_key = false
end
```

**`auto_delete_approval_key`**

This option indicates if queues should be auto-deleted when the number of jobs in
the queue reaches 0.

This option is false by default because of possible race conditions if the
same key is used on several jobs and they are added/removed from the queuues too
quickly.

I would recommend you only use this option if the keys that are used are
unique in some way, or if their use is infrequent.

Usage:

```Ruby
JobClass.auto_delete_approval_key = true
```

**`default_queue_name`**

This option defines the default queue name used for a job that is to be approved.  The
value will default to the same value as the queue name for Resque.

This would be used to simplify approval calls and not have to copy the approval key throughout
the code.

Usage:

```Ruby
JobClass.default_queue_name = "Some queue name"

# A simple alternative to: Resque.enqueue JobClass, some_parameters, approval_key: JobClass.default_queue_name
Resque.enqueue JobClass, some_parameters, requires_approval: true

# A simple alias of: Resque::Plugins::Approve.approve_num(num_approve, JobClass.default_queue_name)
JobClass.approve_one
```

**`max_active_jobs`**

This option is defaulted to -1 (disabled).

This option allows your job to behave as if it auto-approves if the number of active jobs in
the queue is below the limit.  NOTE:  Only jobs that have a `max_active_jobs` value are counted.

In order to signal that this option is active and to count the jobs and place into the approval
queue if there are too many running jobs, you must include `requires_approval` or `approval_key`
to try to place the job into the approval queue.  It is upon placing it into the queue that
the number of running jobs is checked and the auto-enqueing is done.

Because jobs which require approval are auto-enqueued when available, any attempt to enqueue
more than `max_active_jobs` will be blocked and the job will simply stay in the approval queue
even if individually/specifically approved.

When a job that contains this option is run, a module is added which overrides the classes `perform`
method that is used by Resque to approve more jobs when a job is completed.  This ensures/allows
more jobs to be run once the queue is full.

A note on why you may want to use this option.  Resque does a good job of managing enqueued jobs on
a first come first served basis.  The Approval queue does the same thing (by default), but does not
put the queued jobs into the Resque queue.  If you have a job that needs to perform an action a large
number of times, you can enqueue a separate job for each time.  (For
example, if you need to perform an action on every or several items in a table)  You then split the
work into two jobs.  One job to select and enqueue a second job to do the work, and one job to
do the actual work.  This separates the task of picking the records to work on from the actual
work and allows for easier error handling if any single sub-task fails (you don't have to catch and
record it or remember where you were in the loop or whatever.)  The problem if you do this is that you
clog Resque with the large number of small jobs to be performed.  Setting the job with a default delay
queue name and a max_active_jobs allows you simply enqueue the jobs with the parameter
`requires_approval: true`.  The jobs will start immediately and run till all of the jobs are completed,
but at any given time, the total number of jobs in Resque will be `max_active_jobs`.  This prevents
Resque from being clogged up with the small jobs.  Other incoming jobs will have a chance to be
queued, and be performed in a timely manner rather than waiting for the large number of small jobs
to all complete first. 

Usage:

```Ruby
JobClass.max_active_jobs = 10
```

Example usage of the option:

```Ruby
class JobClass
  include Resque::Plugins::Approve

  self.max_active_jobs = 10
  self.default_queue_name = "Some Queue Name"

  def self.perform
    do_something
  end
end

class JobQueuingClass
  class << self
    def perform(*args)
      some_list_of_jobs_to_perform(*args).each do
        # The first `max_active_jobs` number of jobs will be automatically
        # run without explicit approval, then after that, as jobs complete
        # the next job waiting will be approved such that at any tiven time
        # there should be up to `max_active_jobs` running.
        #
        # When the last job is run, the system will stop because there is
        # nothing else to approve.
        Resque.enqueue JobClass, requires_approval: true
      end
    end
  end
end
```

Server Navigation
-----------------

If you include the server exensions, you will be able to use the Resque server
web interface to view pending jobs and to enqueue or delete them as you need.

####Approval Keys

![Approval Keys](https://raw.githubusercontent.com/RealNobody/resque-approve/master/read_me/approval_key_list.png)

####Job Queue

![Job Queue](https://raw.githubusercontent.com/RealNobody/resque-approve/master/read_me/pending_job_queue.png)

####Pending Job

![Pending Job Details](https://raw.githubusercontent.com/RealNobody/resque-approve/master/read_me/job_details.png)

Accessing Histories Progamatically
----------------------------------

You can easily access the list of histories programatically and approve or reject
pending jobs by the approval key used when the job was enqueued.

The simplest method is to use the `Resque::Plugins::Approve` class to approve
or reject jobs using the approval key.

```Ruby
class MyJob
  include Resque::Plugins::Approve
end

Resque::Plugins::Approve.approve_one("approval key")
```

###Approve

The following class methods are available directly from `Resque::Plugins::Approve`

* `approve_one(approval_key)` - Approves the first job that is still pending
  with the passed in key and enqueues it.
  If there are no jobs pending, nothing will happen.  Approvals are not
  cached for future enqueues.  A job can only be approved after it has been enqueued.

* `approve(approval_key)` - Approves  all jobs that are still pending with the
  passed in key and enqueues them in the order that they were originally enqueued.
  If there are no jobs pending, nothing will happen.

* `remove_one(approval_key)` - Removes the first job that is pending from
  the queue without enqueing it.  This rejects the job so that it is not run.

* `remove(approval_key)` - Removes all jobs that are still pending with the
  passed in key without enqueuing them.

###ApprovalKeyList

The approval key list gives you access to the list of queues that may contain
jobs that are pending approval.  Any given queue may or may not have any jobs
in them.

```Ruby
key_list = Resque::Plugins::ApprovalKeyList.new

key_list.job_queues.map(&:approval_key)
key_list.approve_all
```

The following methods are available on an instance of the `ApprovalKeyList`:

* `approve_all` - Approves all jobs on all queues.
* `remove_all` - Removes all jobs from all queues and deletes the queues.
* `job_queues` - An unsorted list of all `PendingJobQueue`s.
* `queues` - A sorted list of all `PendingJobQueue`s.

###PendingJobQueue

A `PendingJobQueue` gives you access to the list of jobs with a particular
approval key.

```Ruby
queue = Resque::Plugins::PendingJobQueue.new("approval key")

queue.jobs
queue.approve_one
queue.approve_all
queue.pop_job
```

The following methods are available on an instance of the `PendingJobQueue`:

* `approve_one` - Enqueues the first job from the queue.
* `approve_num` - Enqueues the first `X` jobs from the queue.
* `approve_all` - Enqueues all jobs in the queue.
* `pop_job` - Enqueues the last (most recently enqueued) job in the queue.
* `remove_one` - Removes the first job from the queue.
* `remove_all` - Removes all jobs from the queue.
* `remove_job_pop` - Removes the last (most recently enqueued) job in the queue.
* `delete` - Removes all jobs from the queue and deletes it.
* `pause` - Pauses a queue and prevents the approval of jobs in the queue.  NOTE:
  Clearing or deleting a queue either one may not resume the queue automatically.
  It is possible for a queue to be empty and be paused.  For best results, resume
  a queue manually before deleting it.
* `resume` - Unpauses a queue and allows the approval of jobs in the queue.  NOTE:
  Resuming a queue will NOT re-issue any approvals that were rejected while the queue
  was paused.  The system simply counts and then tosses approvals that were issueed while
  the queue is paused.  Once you resume the queue, you will have to manually
  issue any approvals you may want.
* `jobs` - A list of the jobs in the queue.

###PendingJob

A `PendingJob` is the job that is currently delayed.

```Ruby
queue = Resque::Plugins::PendingJobQueue.new("approval key")

job = queue.jobs(0, 0).first

job.class_name
job.args
job.enqueue_job
```

The following methods are available on an instance of the `PendingJobQueue`:

* `enqueue_job` - Enqueues the job.  NOTE:  Since this is executed against a specific
  Job, and not the queue, this will approve the job even if the queue is paused
  allowing specific jobs to be approved manually while pausing the rest of the queue.
* `delete` - Deletes the job.
* `class_name` - The class for the job that will be enqueued.
* `args` - The `*arg`s for the job that will be enqueued.
* `approval_key` - The approval key for the job.
* `approval_queue` - The queue that the job will be enqueued to.
* `approval_at` - If specified the time that the job will be enqueued at.
* `queue_time` - The time when the job was initially enqueued.

###Cleaner

The `Cleaner` is provided to audit the Redis keys used by the Approve gem
and make sure that everything is good.  There should be no need for the
`Cleaner` in normal usage, but if you delete queues there is the ability
for race conditions to happen where jobs can be lost.  (Which is why by
default, queues are not deleted.)

```Ruby
Resque::Plugins::Cleaner.cleanup_jobs
```

The following methods are available on the `Cleaner` class:

* `cleanup_jobs` - Scans Redis for any jobs that are not actually in the
  queue that it is supposed to be in and re-adds it.
* `cleanup_queues` - Deletes any queues that do not have any jobs.
  This is a slightly risky scenario as there is a race condition in Redis
  between when we check if the queue is empty and it is deleted where a job
  could be added.
* `purge_all` - Delete all information from Redis related to the `Approve` gem.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
