# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resque::Plugins::Approve::PendingJob do
  let(:key_list) { Resque::Plugins::Approve::ApprovalKeyList.new }
  let!(:key) { Faker::Lorem.sentence }
  let(:job_queue) { Resque::Plugins::Approve::PendingJobQueue.new(key) }
  let(:job_class) { BasicJob }
  let(:no_args_job) do
    job = Resque::Plugins::Approve::PendingJob.new(SecureRandom.uuid, class_name: job_class, args: nil)

    key_list.add_job(job)

    job
  end
  let(:no_hash_args_job) do
    job = Resque::Plugins::Approve::PendingJob.new(SecureRandom.uuid, class_name: job_class, args: [1, "fred", "something else", 888])

    key_list.add_job(job)

    job
  end
  let(:hash_args_job) do
    job = Resque::Plugins::Approve::PendingJob.new(SecureRandom.uuid,
                                                   class_name: job_class,
                                                   args:       [1, "fred", "something else", 888, other_arg: 1, "something else" => "something"])

    key_list.add_job(job)

    job
  end
  let(:approval_only_args_job) do
    job = Resque::Plugins::Approve::PendingJob.new(SecureRandom.uuid, class_name: job_class, args: [approval_key: key])

    key_list.add_job(job)

    job
  end
  let(:approval_require_approval_job) do
    job = Resque::Plugins::Approve::PendingJob.new(SecureRandom.uuid, class_name: job_class, args: [requires_approval: true])

    key_list.add_job(job)

    job
  end
  let(:approval_hash_only_args_job) do
    job = Resque::Plugins::Approve::PendingJob.new(SecureRandom.uuid, class_name: job_class, args: [some_hash: "hash", approval_key: key])

    key_list.add_job(job)

    job
  end
  let(:approval_no_hash_args_job) do
    job = Resque::Plugins::Approve::PendingJob.new(SecureRandom.uuid,
                                                   class_name: job_class,
                                                   args:       [1, "fred", "something else", 888, approval_key: key])

    key_list.add_job(job)

    job
  end
  let(:approval_hash_args_job) do
    job = Resque::Plugins::Approve::PendingJob.new(SecureRandom.uuid,
                                                   class_name: job_class,
                                                   args:       [1,
                                                                "fred",
                                                                "something else",
                                                                888,
                                                                other_arg:       1,
                                                                "approval_key"   => key,
                                                                "something else" => "something"])

    key_list.add_job(job)

    job
  end
  let(:approval_all_args_job) do
    job = Resque::Plugins::Approve::PendingJob.new(SecureRandom.uuid,
                                                   class_name: job_class,
                                                   args:       [1,
                                                                "fred",
                                                                "something else",
                                                                888,
                                                                approval_queue:  "Another Queue",
                                                                approval_at:     2.hours.from_now,
                                                                other_arg:       1,
                                                                "approval_key"   => key,
                                                                "something else" => "something"])

    key_list.add_job(job)

    job
  end

  before(:each) do
    allow(Resque).to receive(:enqueue_to).and_call_original
  end

  describe "initialize" do
    it "extracts delay arguments from job with no argument" do
      expect(no_args_job.args).to eq []
      expect(Resque::Plugins::Approve::PendingJob.new(no_args_job.id).args).to eq []
      expect(no_args_job.approve_options).to eq({}.with_indifferent_access)
    end

    it "extracts delay arguments from job with no hash arguments" do
      expect(no_hash_args_job.args).to eq [1, "fred", "something else", 888]
      expect(Resque::Plugins::Approve::PendingJob.new(no_hash_args_job.id).args).to eq [1, "fred", "something else", 888]
      expect(no_hash_args_job.approve_options).to eq({}.with_indifferent_access)
    end

    it "extracts delay arguments from job with no approval arguments" do
      expect(hash_args_job.args).to eq [1, "fred", "something else", 888, "other_arg" => 1, "something else" => "something"]
      expect(Resque::Plugins::Approve::PendingJob.new(hash_args_job.id).args).
          to eq [1, "fred", "something else", 888, "other_arg" => 1, "something else" => "something"]
      expect(hash_args_job.approve_options).to eq({}.with_indifferent_access)
    end

    it "extracts delay arguments from job with no argument and approval_args" do
      expect(approval_only_args_job.args).to eq []
      expect(Resque::Plugins::Approve::PendingJob.new(approval_only_args_job.id).args).to eq []
      expect(approval_only_args_job.approve_options).to eq("approval_key" => key)
    end

    it "extracts delay arguments from job with no argument and require_approval" do
      expect(approval_require_approval_job.args).to eq []
      expect(Resque::Plugins::Approve::PendingJob.new(approval_require_approval_job.id).args).to eq []
      expect(approval_require_approval_job.approve_options).to eq("approval_key" => "Some_Queue", "requires_approval" => true)
    end

    it "extracts delay arguments from job with only hash arguments and approval_args" do
      expect(approval_hash_only_args_job.args).to eq [{ "some_hash" => "hash" }]
      expect(Resque::Plugins::Approve::PendingJob.new(approval_hash_only_args_job.id).args).to eq [{ "some_hash" => "hash" }]
      expect(approval_hash_only_args_job.approve_options).to eq("approval_key" => key)
    end

    it "extracts delay arguments from job with no hash arguments and approval args" do
      expect(approval_no_hash_args_job.args).to eq [1, "fred", "something else", 888]
      expect(Resque::Plugins::Approve::PendingJob.new(approval_no_hash_args_job.id).args).to eq [1, "fred", "something else", 888]
      expect(approval_no_hash_args_job.approve_options).to eq("approval_key" => key)
    end

    it "extracts delay arguments from job with no approval arguments and approval args" do
      expect(approval_hash_args_job.args).to eq [1, "fred", "something else", 888, "other_arg" => 1, "something else" => "something"]
      expect(Resque::Plugins::Approve::PendingJob.new(approval_hash_args_job.id).args).
          to eq [1, "fred", "something else", 888, "other_arg" => 1, "something else" => "something"]
      expect(approval_hash_args_job.approve_options).to eq("approval_key" => key)
    end

    it "extracts all delay arguments from job with no approval arguments and approval args" do
      expect(approval_all_args_job.args).to eq [1, "fred", "something else", 888, "other_arg" => 1, "something else" => "something"]
      expect(Resque::Plugins::Approve::PendingJob.new(approval_all_args_job.id).args).
          to eq [1, "fred", "something else", 888, "other_arg" => 1, "something else" => "something"]

      expect(approval_all_args_job.approve_options[:approval_key]).to eq key
      expect(approval_all_args_job.approve_options["approval_key"]).to eq key

      expect(approval_all_args_job.approve_options[:approval_queue]).to eq "Another Queue"
      expect(approval_all_args_job.approve_options["approval_queue"]).to eq "Another Queue"

      expect(approval_all_args_job.approve_options[:approval_at].to_time).to be_within(2.seconds).of(2.hours.from_now)
      expect(approval_all_args_job.approve_options["approval_at"].to_time).to be_within(2.seconds).of(2.hours.from_now)
    end
  end

  describe "<=>" do
    let(:a_job) { Resque::Plugins::Approve::PendingJob.new("A") }
    let(:a_job_too) { Resque::Plugins::Approve::PendingJob.new("A") }
    let(:b_job) { Resque::Plugins::Approve::PendingJob.new("B") }

    it "compares two jobs" do
      expect(no_hash_args_job).not_to eq no_args_job
      expect(no_hash_args_job).to eq Resque::Plugins::Approve::PendingJob.new(no_hash_args_job.id)
    end

    it "compares <" do
      expect(a_job).to be < b_job
    end

    it "compares >" do
      expect(b_job).to be > a_job
    end

    it "compares <=" do
      expect(a_job).to be <= b_job
      expect(a_job).to be <= a_job_too
    end

    it "compares >=" do
      expect(b_job).to be >= a_job
      expect(a_job).to be >= a_job
    end
  end

  RSpec.shared_examples "pending job attributes" do
    it "has a class_name" do
      expect(job.class_name).to eq "BasicJob"
    end

    it "has args" do
      expect(job.args).to eq [1, "fred", "something else", 888, "other_arg" => 1, "something else" => "something"]
      expect(Resque::Plugins::Approve::PendingJob.new(job.id).args).
          to eq [1, "fred", "something else", 888, "other_arg" => 1, "something else" => "something"]
    end

    it "has the approval_key" do
      expect(job.approval_key).to eq key
    end

    it "has the approval_queue" do
      expect(job.approval_queue).to eq "Another Queue"
    end

    it "has the approval_at" do
      expect(job.approval_at).to be_within(2.seconds).of(2.hours.from_now)
    end

    it "has the queue_time" do
      expect(job.queue_time).to be_within(2.seconds).of(2.hours.ago)
    end

    it "has the queue" do
      expect(job.queue.approval_key).to eq key
    end
  end

  describe "initialized object" do
    let(:job) { approval_all_args_job }

    before(:each) do
      job

      Timecop.freeze(2.hours.ago) do
        job.save!
      end
    end

    it_behaves_like "pending job attributes"
  end

  describe "saved object" do
    let(:job) { Resque::Plugins::Approve::PendingJob.new(approval_all_args_job.id) }

    before(:each) do
      approval_all_args_job

      Timecop.freeze(2.hours.ago) do
        approval_all_args_job.save!
      end
    end

    it_behaves_like "pending job attributes"
  end

  describe "approval_queue" do
    it "returns the classes default queue" do
      expect(no_args_job.approval_queue).to eq "Some_Queue"
    end
  end

  describe "requires_approval?" do
    it "requires_approval only if approval_key is set" do
      expect(no_args_job).not_to be_requires_approval
      expect(no_hash_args_job).not_to be_requires_approval
      expect(hash_args_job).not_to be_requires_approval
      expect(approval_only_args_job).to be_requires_approval
      expect(approval_no_hash_args_job).to be_requires_approval
      expect(approval_hash_args_job).to be_requires_approval
      expect(approval_all_args_job).to be_requires_approval

      job = Resque::Plugins::Approve::PendingJob.new(SecureRandom.uuid,
                                                     class_name: job_class,
                                                     args:       [1,
                                                                  "fred",
                                                                  "something else",
                                                                  888,
                                                                  approval_queue:  "Another Queue",
                                                                  approval_at:     2.hours.from_now,
                                                                  other_arg:       1,
                                                                  "something else" => "something"])

      expect(job).not_to be_requires_approval
    end

    it "requires approval if requires_approval is passed" do
      expect(approval_require_approval_job).to be_requires_approval
    end

    context "MaxActiveJob" do
      let(:job_class) { MaxActiveJob }
      let(:num_queue) { Resque::Plugins::Approve::PendingJobQueue.new("Some_Queue") }

      before(:each) do
        num_queue.reset_running
      end

      it "does not require approval if num jobs below max" do
        expect(approval_require_approval_job).not_to be_requires_approval

        expect(approval_require_approval_job.args).not_to eq ["approval_key" => "Some_Queue"]
        expect(approval_require_approval_job.uncompressed_args).to eq ["approval_key" => "Some_Queue"]
        expect(Resque::Plugins::Approve::PendingJob.new(approval_require_approval_job.id).uncompressed_args).to eq ["approval_key" => "Some_Queue"]
        expect(approval_require_approval_job.approve_options).to eq("approval_key" => "Some_Queue", "requires_approval" => true)
      end

      it "does require approval if num jobs above max" do
        10.times { num_queue.increment_running }

        expect(approval_require_approval_job).to be_requires_approval

        expect(approval_require_approval_job.args).not_to eq ["approval_key" => "Some_Queue"]
        expect(approval_require_approval_job.uncompressed_args).to eq ["approval_key" => "Some_Queue"]
        expect(Resque::Plugins::Approve::PendingJob.new(approval_require_approval_job.id).uncompressed_args).to eq ["approval_key" => "Some_Queue"]
        expect(approval_require_approval_job.approve_options).to eq("approval_key" => "Some_Queue", "requires_approval" => true)
      end

      it "calls the perform function" do
        allow(Resque.logger).to receive(:warn).and_call_original

        MaxActiveJob.perform(*approval_require_approval_job.args)

        expect(Resque.logger).to have_received(:warn).with("Args:\n[]").exactly(2).times
      end

      it "does not approve if number of running jobs too high" do
        approval_require_approval_job

        expect(Resque::Plugins::Approve::PendingJobQueue.new("Some_Queue").num_jobs).to eq 1

        10.times { num_queue.increment_running }

        allow(Resque.logger).to receive(:warn).and_call_original

        job_class.approve_one

        expect(Resque.logger).not_to have_received(:warn)
        expect(Resque::Plugins::Approve::PendingJobQueue.new("Some_Queue").num_jobs).to eq 1

        expect(num_queue.num_running.to_i).to eq 10
      end

      it "approves the next item in the queue" do
        allow(Resque::Plugins::Approve).to receive(:approve_one).and_call_original

        MaxActiveJob.perform(*approval_require_approval_job.args)

        expect(Resque::Plugins::Approve).to have_received(:approve_one).with("Some_Queue").exactly(2).times
      end

      it "approves the next item in the queue even if there is an exception" do
        allow(Resque.logger).to receive(:warn).with("Args:\n[]").and_raise "Error"
        allow(Resque::Plugins::Approve).to receive(:approve_one).and_call_original

        expect { MaxActiveJob.perform(*approval_require_approval_job.args) }.to raise_error

        expect(Resque.logger).to have_received(:warn).with("Args:\n[]").exactly(2).times
        expect(Resque::Plugins::Approve).to have_received(:approve_one).with("Some_Queue").exactly(2).times
      end

      it "approves the next item in the queue if non-default queue used" do
        job = Resque::Plugins::Approve::PendingJob.new(SecureRandom.uuid, class_name: job_class, args: [approval_key: "New Key"])

        key_list.add_job(job)

        allow(Resque.logger).to receive(:warn).and_call_original
        allow(Resque::Plugins::Approve).to receive(:approve_one).and_call_original

        MaxActiveJob.perform(*job.args)

        expect(Resque.logger).to have_received(:warn).with("Args:\n[]").exactly(2).times
        expect(Resque::Plugins::Approve).to have_received(:approve_one).with("New Key").exactly(2).times
      end

      it "approves the next item in the queue if non-default queue used and queue full" do
        job = Resque::Plugins::Approve::PendingJob.new(SecureRandom.uuid, class_name: job_class, args: [requires_approval: true])

        10.times { num_queue.increment_running }
        key_list.add_job(job)

        allow(Resque.logger).to receive(:warn).and_call_original
        allow(Resque::Plugins::Approve).to receive(:approve_one).and_call_original

        MaxActiveJob.perform(*job.args)

        expect(Resque::Plugins::Approve).to have_received(:approve_one).with("Some_Queue").exactly(2).times
        expect(Resque.logger).to have_received(:warn).with("Args:\n[]").exactly(2).times
        expect(num_queue.num_running.to_i).to eq 9
      end

      it "enqueues the job" do
        allow(Resque.logger).to receive(:warn).and_call_original
        allow(Resque::Plugins::Approve).to receive(:approve_one).and_call_original

        Resque.enqueue MaxActiveJob, requires_approval: true

        expect(Resque.logger).to have_received(:warn).with("Args:\n[]")
        expect(Resque::Plugins::Approve).to have_received(:approve_one).with("Some_Queue")
      end

      it "enqueues a job with arguments" do
        allow(Resque.logger).to receive(:warn).and_call_original
        allow(Resque::Plugins::Approve).to receive(:approve_one).and_call_original

        Resque.enqueue MaxActiveJob, param: "value", requires_approval: true

        expect(Resque.logger).to have_received(:warn).with("Args:\n[{\"param\":\"value\"}]")
        expect(Resque::Plugins::Approve).to have_received(:approve_one).with("Some_Queue")
      end

      it "does not enqueue a job if paused" do
        num_queue.pause

        expect(num_queue.num_jobs).to be_zero

        allow(Resque.logger).to receive(:warn).and_call_original
        allow(Resque::Plugins::Approve).to receive(:approve_one).and_call_original

        Resque.enqueue MaxActiveJob, requires_approval: true

        expect(Resque.logger).not_to have_received(:warn).with("Args:\n[]")
        expect(Resque::Plugins::Approve).not_to have_received(:approve_one).with("Some_Queue")

        expect(num_queue.num_jobs).to eq 1
      end
    end
  end

  describe "enqueue_job" do
    it "enqueues the job without any parameters" do
      no_args_job.enqueue_job

      expect(Resque).to have_received(:enqueue_to).with("Some_Queue", BasicJob)
    end

    it "enqueues the job without any parameters" do
      key_list.add_job(no_args_job)

      no_args_job.enqueue_job
    end

    it "delay enqueues a job" do
      allow(Resque).to receive(:enqueue_at_with_queue).and_call_original

      Timecop.freeze do
        approval_all_args_job.enqueue_job

        expect(Resque).
            to have_received(:enqueue_at_with_queue).
                with("Another Queue",
                     2.hours.from_now,
                     BasicJob,
                     1,
                     "fred",
                     "something else",
                     888,
                     "other_arg"      => 1,
                     "something else" => "something")
      end
    end
  end

  describe "delete" do
    it "works with an already deleted job" do
      no_args_job.delete

      expect { Resque::Plugins::Approve::PendingJob.new(no_args_job.id).delete }.not_to raise_exception
    end

    it "deletes the job" do
      no_args_job.delete

      expect(Resque::Plugins::Approve::PendingJob.new(no_args_job.id).class_name).not_to be
    end

    it "removes the job from the queue" do
      no_args_job.delete

      expect(Resque::Plugins::Approve::PendingJobQueue.new(key).num_jobs).to be_zero
    end

    it "does not remoe the queue" do
      no_args_job.delete

      expect(key_list.num_queues).to eq 1
    end

    it "does delete the queue if the class says to" do
      job = Resque::Plugins::Approve::PendingJob.new SecureRandom.uuid,
                                                     class_name: AutoDeleteApprovalKeyJob,
                                                     args:       [approval_key: key]

      key_list.add_job(job)

      expect(Resque::Plugins::Approve::ApprovalKeyList.new.num_queues).to eq 1
      expect(Resque::Plugins::Approve::PendingJobQueue.new(key).num_jobs).to eq 1

      job.delete

      expect(Resque::Plugins::Approve::PendingJobQueue.new(key).num_jobs).to eq 0
      expect(Resque::Plugins::Approve::ApprovalKeyList.new.num_queues).to eq 0
    end
  end

  describe "max_active_jobs?" do
    it "returns false if not set on class" do
      expect(no_args_job.max_active_jobs?).to be_falsey
    end

    context "MaxActiveJob" do
      let(:job_class) { MaxActiveJob }

      it "returns true if a max is set" do
        expect(no_args_job.max_active_jobs?).to be_truthy
      end
    end
  end

  describe "requires_approval" do
    context "DefaultApprovalQueue" do
      let(:job_class) { DefaultApprovalQueue }

      it "sets the key to the default queue" do
        expect(approval_require_approval_job.args).to eq []
        expect(Resque::Plugins::Approve::PendingJob.new(approval_require_approval_job.id).args).to eq []
        expect(approval_require_approval_job.approve_options).to eq("approval_key" => "Default Approval Queue", "requires_approval" => true)
      end
    end
  end

  describe "max_active_jobs" do
    it "returns -1 if not set on class" do
      expect(no_args_job.max_active_jobs).to eq(-1)
    end

    context "MaxActiveJob" do
      let(:job_class) { MaxActiveJob }

      it "returns value if max set" do
        expect(no_args_job.max_active_jobs).to eq 10
      end
    end
  end

  describe "uncompressed_args" do
    let(:test_args) { [1, "fred", "something else", 888, "approval_key" => "Some_Queue", "other_arg" => 1, "something else" => "something"] }
    let(:compressed_args) { [{ :resque_compressed => true, :payload => MaxActiveJob.compressed_args(test_args) }] }
    let(:job_class) { MaxActiveJob }

    it "decompresses args" do
      job = Resque::Plugins::Approve::PendingJob.new(SecureRandom.uuid,
                                                     class_name: job_class,
                                                     args:       compressed_args)

      key_list.add_job(job)

      expect(Resque::Plugins::Approve::PendingJob.new(job.id).uncompressed_args).to eq test_args
    end

    it "does not decompress args if not compressed" do
      job = Resque::Plugins::Approve::PendingJob.new(SecureRandom.uuid,
                                                     class_name: job_class,
                                                     args:       test_args)

      key_list.add_job(job)

      expect(Resque::Plugins::Approve::PendingJob.new(job.id).uncompressed_args).to eq test_args
    end

    context "Not compressable" do
      let(:test_args) { [1, "fred", "something else", 888, "other_arg" => 1, "something else" => "something"] }

      it "does not decompress args if not compressable" do
        job = Resque::Plugins::Approve::PendingJob.new(SecureRandom.uuid,
                                                       class_name: BasicJob,
                                                       args:       test_args)

        key_list.add_job(job)

        expect(Resque::Plugins::Approve::PendingJob.new(job.id).uncompressed_args).to eq test_args
      end
    end
  end
end
