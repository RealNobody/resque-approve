# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resque::Plugins::Approve::Cleaner do
  let!(:key_list) { Resque::Plugins::Approve::ApprovalKeyList.new }
  let!(:keys) { Array.new(3) { Faker::Lorem.sentence } }
  let!(:jobs) do
    keys.map do |approval_key|
      Array.new(3) do
        job = Resque::Plugins::Approve::PendingJob.new(SecureRandom.uuid, class_name: BasicJob, args: [approval_key: approval_key])

        key_list.add_job(job)

        job
      end
    end
  end

  describe "purge_all" do
    it "deletes all jobs" do
      Resque::Plugins::Approve::Cleaner.purge_all

      jobs.flatten.each do |job|
        expect(Resque::Plugins::Approve::PendingJob.new(job.id).class_name).to be_blank
      end
    end

    it "deletes all queues" do
      Resque::Plugins::Approve::Cleaner.purge_all

      keys.each do |approval_key|
        expect(Resque::Plugins::Approve::PendingJobQueue.new(approval_key).num_jobs).to be_zero
      end
    end

    it "deletes all queue names" do
      Resque::Plugins::Approve::Cleaner.purge_all

      expect(key_list.num_queues).to be_zero
    end
  end

  describe "cleanup_jobs" do
    it "re-adds the job to the queue" do
      job = jobs.first.first

      queue = Resque::Plugins::Approve::PendingJobQueue.new(job.approval_key)

      queue.remove_job(job)
      expect(queue.num_jobs).to eq 2
      expect(queue.jobs).not_to be_include(job)

      Resque::Plugins::Approve::Cleaner.cleanup_jobs

      queue = Resque::Plugins::Approve::PendingJobQueue.new(job.approval_key)

      expect(queue.num_jobs).to eq 3
      expect(queue.jobs).to be_include(job)
    end

    it "re-adds the queue to the list" do
      job = jobs.first.first

      key_list.remove_key(job.approval_key)

      list = Resque::Plugins::Approve::ApprovalKeyList.new
      expect(list.num_queues).to eq 2
      expect(list.queues.map(&:approval_key)).not_to be_include(job.approval_key)

      Resque::Plugins::Approve::Cleaner.cleanup_jobs

      list = Resque::Plugins::Approve::ApprovalKeyList.new
      expect(list.num_queues).to eq 3
      expect(list.queues.map(&:approval_key)).to be_include(job.approval_key)
    end
  end

  describe "cleanup_queues" do
    it "removes empty queues" do
      job = jobs.first.first

      jobs.first.each(&:delete)

      list = Resque::Plugins::Approve::ApprovalKeyList.new
      expect(list.num_queues).to eq 3
      expect(list.queues.map(&:approval_key)).to be_include(job.approval_key)

      Resque::Plugins::Approve::Cleaner.cleanup_queues

      list = Resque::Plugins::Approve::ApprovalKeyList.new
      expect(list.num_queues).to eq 2
      expect(list.queues.map(&:approval_key)).not_to be_include(job.approval_key)
    end
  end
end
