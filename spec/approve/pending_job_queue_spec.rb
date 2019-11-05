# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resque::Plugins::Approve::PendingJobQueue do
  let(:key_list) { Resque::Plugins::Approve::ApprovalKeyList.new }
  let!(:key) { Faker::Lorem.sentence }
  let(:job_queue) { Resque::Plugins::Approve::PendingJobQueue.new(key) }
  let(:job_class) { BasicJob }
  let!(:jobs) do
    Array.new(4) do |index|
      Timecop.freeze((5 - index).hours.ago) do
        job = Resque::Plugins::Approve::PendingJob.new(SecureRandom.uuid, class_name: job_class, args: [index, approval_key: key])

        key_list.add_job(job)

        job
      end
    end
  end

  before(:each) do
    allow(Resque).to receive(:enqueue_to).and_call_original
  end

  after(:each) do
    job_queue.resume
  end

  describe "delete" do
    it "deletes all jobs" do
      job_queue.delete

      jobs.flatten.each do |job|
        expect(Resque::Plugins::Approve::PendingJob.new(job.id).class_name).to be_blank
      end
    end

    it "removes all jobs from the queue" do
      job_queue.delete

      expect(job_queue.num_jobs).to eq 0
    end

    it "removes all jobs from the queue if paused" do
      job_queue.pause
      job_queue.delete

      expect(job_queue.num_jobs).to eq 0
    end

    it "does not remove the key from the key_list" do
      job_queue.delete

      expect(key_list.queue_keys).to be_include key
    end

    context("auto-delete") do
      let(:job_class) { AutoDeleteApprovalKeyJob }

      it "removes the key from the key_list" do
        job_queue.delete

        expect(key_list.queue_keys).not_to be_include key
      end
    end
  end

  describe "verify_job" do
    let(:other_key) { Faker::Lorem.sentence }

    it "adds the queue to the list" do
      job = Resque::Plugins::Approve::PendingJob.new(SecureRandom.uuid, class_name: job_class, args: [approval_key: other_key])

      job.save!

      expect(key_list.queue_keys).not_to be_include other_key

      job_queue.verify_job(job)

      expect(Resque::Plugins::Approve::ApprovalKeyList.new.queue_keys).to be_include other_key
    end

    it "adds the job to the list" do
      job = Resque::Plugins::Approve::PendingJob.new(SecureRandom.uuid, class_name: job_class, args: [approval_key: other_key])

      job.save!

      expect(job_queue.jobs).not_to be_include job

      job_queue.verify_job(job)

      expect(job_queue.jobs).to be_include job

      expect { job_queue.verify_job(job) }.not_to(change { job_queue.num_jobs })
    end
  end

  describe "approve_one" do
    it "enqueues the first job" do
      job_queue.approve_one

      expect(Resque).to have_received(:enqueue_to).with "Some_Queue", BasicJob, 0
      expect(Resque).not_to have_received(:enqueue_to).with "Some_Queue", BasicJob, 1
      expect(Resque).not_to have_received(:enqueue_to).with "Some_Queue", BasicJob, 2
      expect(Resque).not_to have_received(:enqueue_to).with "Some_Queue", BasicJob, 3

      expect(job_queue.jobs).not_to be_include jobs[0]
      expect(job_queue.num_jobs).to eq 3
    end

    it "does not enqueues the first job if paused" do
      job_queue.pause
      job_queue.approve_one

      expect(Resque).not_to have_received(:enqueue_to).with "Some_Queue", BasicJob, 0
      expect(Resque).not_to have_received(:enqueue_to).with "Some_Queue", BasicJob, 1
      expect(Resque).not_to have_received(:enqueue_to).with "Some_Queue", BasicJob, 2
      expect(Resque).not_to have_received(:enqueue_to).with "Some_Queue", BasicJob, 3

      expect(job_queue.jobs).to be_include jobs[0]
      expect(job_queue.num_jobs).to eq 4
    end
  end

  describe "pop_job" do
    it "enqueues the last job" do
      job_queue.pop_job

      expect(Resque).to have_received(:enqueue_to).with "Some_Queue", BasicJob, 3
      expect(Resque).not_to have_received(:enqueue_to).with "Some_Queue", BasicJob, 0
      expect(Resque).not_to have_received(:enqueue_to).with "Some_Queue", BasicJob, 1
      expect(Resque).not_to have_received(:enqueue_to).with "Some_Queue", BasicJob, 2

      expect(job_queue.jobs).not_to be_include jobs[3]
      expect(job_queue.num_jobs).to eq 3
    end

    it "does not enqueues the last job if paused" do
      job_queue.pause
      job_queue.pop_job

      expect(Resque).not_to have_received(:enqueue_to).with "Some_Queue", BasicJob, 3
      expect(Resque).not_to have_received(:enqueue_to).with "Some_Queue", BasicJob, 0
      expect(Resque).not_to have_received(:enqueue_to).with "Some_Queue", BasicJob, 1
      expect(Resque).not_to have_received(:enqueue_to).with "Some_Queue", BasicJob, 2

      expect(job_queue.jobs).to be_include jobs[3]
      expect(job_queue.num_jobs).to eq 4
    end
  end

  describe "approve_all" do
    it "enqueues all jobs" do
      job_queue.approve_all

      expect(Resque).to have_received(:enqueue_to).with "Some_Queue", BasicJob, 0
      expect(Resque).to have_received(:enqueue_to).with "Some_Queue", BasicJob, 1
      expect(Resque).to have_received(:enqueue_to).with "Some_Queue", BasicJob, 2
      expect(Resque).to have_received(:enqueue_to).with "Some_Queue", BasicJob, 3

      expect(job_queue.jobs).to be_blank
    end

    it "does not enqueues all jobs if paused" do
      expect(job_queue.num_jobs).to eq 4

      job_queue.pause
      job_queue.approve_all

      expect(Resque).not_to have_received(:enqueue_to).with "Some_Queue", BasicJob, 0
      expect(Resque).not_to have_received(:enqueue_to).with "Some_Queue", BasicJob, 1
      expect(Resque).not_to have_received(:enqueue_to).with "Some_Queue", BasicJob, 2
      expect(Resque).not_to have_received(:enqueue_to).with "Some_Queue", BasicJob, 3

      expect(job_queue.num_jobs).to eq 4
    end
  end

  describe "remove_one" do
    it "removes the first job" do
      job_queue.remove_one

      expect(Resque).not_to have_received(:enqueue_to).with "Some_Queue", BasicJob, 0
      expect(Resque).not_to have_received(:enqueue_to).with "Some_Queue", BasicJob, 1
      expect(Resque).not_to have_received(:enqueue_to).with "Some_Queue", BasicJob, 2
      expect(Resque).not_to have_received(:enqueue_to).with "Some_Queue", BasicJob, 3

      expect(job_queue.jobs).not_to be_include jobs[0]
      expect(job_queue.num_jobs).to eq 3
    end

    it "removes the first job" do
      job_queue.pause
      job_queue.remove_one

      expect(Resque).not_to have_received(:enqueue_to).with "Some_Queue", BasicJob, 0
      expect(Resque).not_to have_received(:enqueue_to).with "Some_Queue", BasicJob, 1
      expect(Resque).not_to have_received(:enqueue_to).with "Some_Queue", BasicJob, 2
      expect(Resque).not_to have_received(:enqueue_to).with "Some_Queue", BasicJob, 3

      expect(job_queue.jobs).not_to be_include jobs[0]
      expect(job_queue.num_jobs).to eq 3
    end
  end

  describe "remove_job_pop" do
    it "removes the last job" do
      job_queue.remove_job_pop

      expect(Resque).not_to have_received(:enqueue_to).with "Some_Queue", BasicJob, 3
      expect(Resque).not_to have_received(:enqueue_to).with "Some_Queue", BasicJob, 0
      expect(Resque).not_to have_received(:enqueue_to).with "Some_Queue", BasicJob, 1
      expect(Resque).not_to have_received(:enqueue_to).with "Some_Queue", BasicJob, 2

      expect(job_queue.jobs).not_to be_include jobs[3]
      expect(job_queue.num_jobs).to eq 3
    end

    it "removes the last job if paused" do
      job_queue.pause
      job_queue.remove_job_pop

      expect(Resque).not_to have_received(:enqueue_to).with "Some_Queue", BasicJob, 3
      expect(Resque).not_to have_received(:enqueue_to).with "Some_Queue", BasicJob, 0
      expect(Resque).not_to have_received(:enqueue_to).with "Some_Queue", BasicJob, 1
      expect(Resque).not_to have_received(:enqueue_to).with "Some_Queue", BasicJob, 2

      expect(job_queue.jobs).not_to be_include jobs[3]
      expect(job_queue.num_jobs).to eq 3
    end
  end

  describe "remove_all" do
    it "removes all jobs" do
      job_queue.remove_all

      expect(Resque).not_to have_received(:enqueue_to).with "Some_Queue", BasicJob, 0
      expect(Resque).not_to have_received(:enqueue_to).with "Some_Queue", BasicJob, 1
      expect(Resque).not_to have_received(:enqueue_to).with "Some_Queue", BasicJob, 2
      expect(Resque).not_to have_received(:enqueue_to).with "Some_Queue", BasicJob, 3

      expect(job_queue.jobs).to be_blank
    end

    it "removes all jobs" do
      job_queue.pause
      job_queue.remove_all

      expect(Resque).not_to have_received(:enqueue_to).with "Some_Queue", BasicJob, 0
      expect(Resque).not_to have_received(:enqueue_to).with "Some_Queue", BasicJob, 1
      expect(Resque).not_to have_received(:enqueue_to).with "Some_Queue", BasicJob, 2
      expect(Resque).not_to have_received(:enqueue_to).with "Some_Queue", BasicJob, 3

      expect(job_queue.jobs).to be_blank
    end
  end

  describe "paged_jobs" do
    let!(:jobs) do
      Array.new(30) do |index|
        job = Resque::Plugins::Approve::PendingJob.new(SecureRandom.uuid, class_name: job_class, args: [index, approval_key: key])

        key_list.add_job(job)

        job
      end
    end

    it "defaults to the first 20 jobs" do
      expect(job_queue.paged_jobs).to eq jobs[0..19]
    end

    it "pages jobs" do
      expect(job_queue.paged_jobs(4, 3)).to eq jobs[9..11]
    end

    it "deals with too small a page" do
      expect(job_queue.paged_jobs(-4, 3)).to eq jobs[0..2]
    end

    it "deals with too large a page" do
      expect(job_queue.paged_jobs(400, 3)).to eq jobs[0..2]
    end

    it "deals with invalid page size" do
      expect(job_queue.paged_jobs(4, 0)).to eq jobs[0..19]
    end
  end

  describe "num_jobs" do
    it "returns the number of jobs" do
      expect(job_queue.num_jobs).to eq 4
    end
  end

  describe "first_enqueued" do
    it "returns the time of the first enqueued item" do
      4.times do |index|
        expect(job_queue.first_enqueued).to be_within(1.second).of((5 - index).hours.ago)

        job_queue.remove_one
      end

      expect(job_queue.first_enqueued).to be_nil
    end
  end

  describe "pause/resume" do
    it "is not paused by default" do
      expect(job_queue).not_to be_paused
    end

    it "can be paused" do
      expect(job_queue).not_to be_paused
      job_queue.pause
      expect(job_queue).to be_paused
      job_queue.pause
      expect(job_queue).to be_paused
    end

    it "can be resumed" do
      expect(job_queue).not_to be_paused
      job_queue.resume
      expect(job_queue).not_to be_paused
      job_queue.pause
      expect(job_queue).to be_paused
      job_queue.resume
      expect(job_queue).not_to be_paused
    end
  end
end
