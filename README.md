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
  auto_delete_approval_key = false
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

Server Navigation
-----------------

If you include the server exensions, you will be able to use the Resque server
web interface to view pending jobs and to enqueue or delete them as you need.

####Approval Keys

![Approval Keys](https://raw.githubusercontent.com/RealNobody/resque-approve/master/read_me/approval_key_list.png)

####Job Queue

![Job Queue](https://raw.githubusercontent.com/RealNobody/resque-approve/master/read_me/pending_job_queue.png)

####Pending Job

![Pending JobHistory](https://raw.githubusercontent.com/RealNobody/resque-approve/master/read_me/job_details.png)


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
* `approve_all` - Enqueues all jobs in the queue.
* `pop_job` - Enqueues the last (most recently enqueued) job in the queue.
* `remove_one` - Removes the first job from the queue.
* `remove_all` - Removes all jobs from the queue.
* `remove_job_pop` - Removes the last (most recently enqueued) job in the queue.
* `delete` - Removes all jobs from the queue and deletes it.
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

* `enqueue_job` - Enqueues the job.
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
* `cleanup_jobs` - Deletes any queues that do not have any jobs.
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
