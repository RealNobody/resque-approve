# frozen_string_literal: true

require "rails_helper"

# rubocop:disable Layout/AlignHash
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
      expect(no_args_job.approve_options).to eq({}.with_indifferent_access)
    end

    it "extracts delay arguments from job with no hash arguments" do
      expect(no_hash_args_job.args).to eq [1, "fred", "something else", 888]
      expect(no_hash_args_job.approve_options).to eq({}.with_indifferent_access)
    end

    it "extracts delay arguments from job with no approval arguments" do
      expect(hash_args_job.args).to eq [1, "fred", "something else", 888, "other_arg" => 1, "something else" => "something"]
      expect(hash_args_job.approve_options).to eq({}.with_indifferent_access)
    end

    it "extracts delay arguments from job with no argument and approval_args" do
      expect(approval_only_args_job.args).to eq []
      expect(approval_only_args_job.approve_options).to eq("approval_key" => key)
    end

    it "extracts delay arguments from job with no hash arguments and approval args" do
      expect(approval_no_hash_args_job.args).to eq [1, "fred", "something else", 888]
      expect(approval_no_hash_args_job.approve_options).to eq("approval_key" => key)
    end

    it "extracts delay arguments from job with no approval arguments and approval args" do
      expect(approval_hash_args_job.args).to eq [1, "fred", "something else", 888, "other_arg" => 1, "something else" => "something"]
      expect(approval_hash_args_job.approve_options).to eq("approval_key" => key)
    end

    it "extracts all delay arguments from job with no approval arguments and approval args" do
      expect(approval_all_args_job.args).to eq [1, "fred", "something else", 888, "other_arg" => 1, "something else" => "something"]

      expect(approval_all_args_job.approve_options[:approval_key]).to eq key
      expect(approval_all_args_job.approve_options["approval_key"]).to eq key

      expect(approval_all_args_job.approve_options[:approval_queue]).to eq "Another Queue"
      expect(approval_all_args_job.approve_options["approval_queue"]).to eq "Another Queue"

      expect(approval_all_args_job.approve_options[:approval_at]).to be_within(2.seconds).of(2.hours.from_now)
      expect(approval_all_args_job.approve_options["approval_at"]).to be_within(2.seconds).of(2.hours.from_now)
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
    end

    it "has the approval_key" do
      expect(job.approval_key).to eq key
    end

    it "has the approval_queue" do
      expect(job.approval_queue).to eq "Another Queue"
    end

    it "has the approval_at" do
      expect(job.approval_at).to be_within(1.second).of(2.hours.from_now)
    end

    it "has the queue_time" do
      expect(job.queue_time).to be_within(1.second).of(2.hours.ago)
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
end
# rubocop:enable Layout/AlignHash
