# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resque::Plugins::Approve do
  let(:job) { BasicJob }
  let(:approval_key) { "approval key #{Faker::Lorem.sentence}" }
  let(:test_args_without_hash) do
    rand_args = []
    rand_args << Faker::Lorem.sentence
    rand_args << Faker::Lorem.paragraph
    rand_args << SecureRandom.uuid.to_s
    rand_args << rand(0..1_000_000_000_000_000_000_000_000).to_s
    rand_args << rand(0..1_000_000_000_000).seconds.ago.to_s
    rand_args << rand(0..1_000_000_000_000).seconds.from_now.to_s
    rand_args << Array.new(rand(1..5)) { Faker::Lorem.word }

    rand_args.sample(rand(3..rand_args.length))
  end
  let(:test_args_with_hash) do
    rand_args = []
    rand_args << Faker::Lorem.sentence
    rand_args << Faker::Lorem.paragraph
    rand_args << SecureRandom.uuid.to_s
    rand_args << rand(0..1_000_000_000_000_000_000_000_000).to_s
    rand_args << rand(0..1_000_000_000_000).seconds.ago.to_s
    rand_args << rand(0..1_000_000_000_000).seconds.from_now.to_s
    rand_args << Array.new(rand(1..5)) { Faker::Lorem.word }
    rand_args << Array.new(rand(1..5)).each_with_object({}) do |_nil_value, sub_hash|
      sub_hash[Faker::Lorem.word] = Faker::Lorem.word
    end

    rand_args = rand_args.sample(rand(3..rand_args.length))

    options_hash                    = {}
    options_hash[Faker::Lorem.word] = Faker::Lorem.sentence
    options_hash[Faker::Lorem.word] = Faker::Lorem.paragraph
    options_hash[Faker::Lorem.word] = SecureRandom.uuid.to_s
    options_hash[Faker::Lorem.word] = rand(0..1_000_000_000_000_000_000_000_000).to_s
    options_hash[Faker::Lorem.word] = rand(0..1_000_000_000_000).seconds.ago.to_s
    options_hash[Faker::Lorem.word] = rand(0..1_000_000_000_000).seconds.from_now.to_s
    options_hash[Faker::Lorem.word] = Array.new(rand(1..5)) { Faker::Lorem.word }
    options_hash[Faker::Lorem.word] = Array.new(rand(1..5)).
        each_with_object({}) do |_nil_value, sub_hash|
      sub_hash[Faker::Lorem.word] = Faker::Lorem.word
    end

    rand_args << options_hash.slice(*options_hash.keys.sample(rand(5..options_hash.keys.length)))

    rand_args
  end
  let(:test_args_without_hash_approve) do
    [*test_args_without_hash, approval_key: approval_key]
  end
  let(:test_args_with_hash_approve) do
    test_args = test_args_with_hash.dup
    test_args << test_args.pop.merge(approval_key: approval_key)

    test_args
  end

  before(:each) do
    allow(BasicJob).to receive(:perform)
  end

  it "has auto_delete_approval_key" do
    expect(BasicJob.auto_delete_approval_key).to be_falsey
  end

  it "has max_active_jobs" do
    expect(BasicJob.max_active_jobs).to eq(-1)
  end

  it "has default_queue_name" do
    expect(BasicJob.default_queue_name).to eq "Some_Queue"
  end

  it "does not delay jobs that are enqueued without delay args" do
    Resque.enqueue BasicJob, *test_args_with_hash

    expect(BasicJob).to have_received(:perform).with(*test_args_with_hash)
  end

  it "does not delay jobs that are enqueued without delay args no options" do
    Resque.enqueue BasicJob, *test_args_without_hash

    expect(BasicJob).to have_received(:perform).with(*test_args_without_hash)
  end

  it "delays jobs that are enqueued with the delay args" do
    Resque.enqueue BasicJob, *test_args_with_hash_approve

    expect(BasicJob).not_to have_received(:perform)
  end

  it "delays jobs that are enqueued with the delay args that did not have other options" do
    Resque.enqueue BasicJob, *test_args_without_hash_approve

    expect(BasicJob).not_to have_received(:perform)
  end

  context "end-to-end testing" do
    let(:job_order) { [0, 1].sample(100) }
    let(:approve_jobs) { [test_args_without_hash_approve, test_args_with_hash_approve] }
    let(:param_jobs) { [test_args_without_hash, test_args_with_hash] }
    let(:jobs) { [approve_jobs[job_order.first], approve_jobs[job_order.last]] }

    it "does not release a job for the wrong key" do
      jobs.each { |job_args| Resque.enqueue BasicJob, *job_args }

      expect(BasicJob).not_to have_received(:perform)

      Resque::Plugins::Approve.approve "any key"

      expect(BasicJob).not_to have_received(:perform)
    end

    it "releases one job" do
      jobs.each do |job_args|
        Resque.enqueue BasicJob, *job_args
      end

      expect(BasicJob).not_to have_received(:perform)

      Resque::Plugins::Approve.approve_one approval_key

      expect(BasicJob).to have_received(:perform).with(*param_jobs[job_order.first])
      expect(BasicJob).not_to have_received(:perform).with(*param_jobs[job_order.last])
    end

    it "releases a count of jobs" do
      jobs.each do |job_args|
        Resque.enqueue BasicJob, *job_args
      end

      expect(BasicJob).not_to have_received(:perform)

      Resque::Plugins::Approve.approve_num 3, approval_key

      expect(BasicJob).to have_received(:perform).with(*param_jobs[job_order.first])
      expect(BasicJob).to have_received(:perform).with(*param_jobs[job_order.last])
    end

    it "releases all jobs" do
      jobs.each { |job_args| Resque.enqueue BasicJob, *job_args }

      expect(BasicJob).not_to have_received(:perform)

      Resque::Plugins::Approve.approve approval_key

      expect(BasicJob).to have_received(:perform).with(*param_jobs[job_order.first])
      expect(BasicJob).to have_received(:perform).with(*param_jobs[job_order.last])
    end

    it "deletes all jobs" do
      jobs.each { |job_args| Resque.enqueue BasicJob, *job_args }

      expect(BasicJob).not_to have_received(:perform)
      expect(Resque::Plugins::Approve::PendingJobQueue.new(approval_key).num_jobs).to eq 2

      Resque::Plugins::Approve.remove approval_key

      expect(BasicJob).not_to have_received(:perform)
      expect(Resque::Plugins::Approve::PendingJobQueue.new(approval_key).num_jobs).to be_zero
    end

    it "deletes one job" do
      jobs.each { |job_args| Resque.enqueue BasicJob, *job_args }

      expect(BasicJob).not_to have_received(:perform)
      expect(Resque::Plugins::Approve::PendingJobQueue.new(approval_key).num_jobs).to eq 2

      Resque::Plugins::Approve.remove_one approval_key

      expect(BasicJob).not_to have_received(:perform)
      expect(Resque::Plugins::Approve::PendingJobQueue.new(approval_key).num_jobs).to eq 1
    end
  end

  describe "before_perform_approve" do
    it "returns true if the job is not to be approved" do
      expect(BasicJob.before_perform_approve(*test_args_without_hash)).to be_truthy
      expect { BasicJob.before_perform_approve(*test_args_without_hash) }.not_to(change { test_args_without_hash })
      expect(BasicJob.before_perform_approve(*test_args_with_hash)).to be_truthy
      expect { BasicJob.before_perform_approve(*test_args_with_hash) }.not_to(change { test_args_with_hash })
    end

    it "raises Resque::Job::DontPerform if it is to be approved" do
      expect { BasicJob.before_perform_approve(*test_args_without_hash_approve) }.to raise_exception(Resque::Job::DontPerform)
      expect { BasicJob.before_perform_approve(*test_args_with_hash_approve) }.to raise_exception(Resque::Job::DontPerform)
    end
  end

  describe "before_enqueue_approve" do
    it "returns true if the job is not to be approved" do
      expect(BasicJob.before_enqueue_approve(*test_args_without_hash)).to be_truthy
      expect { BasicJob.before_enqueue_approve(*test_args_without_hash) }.not_to(change { test_args_without_hash })
      expect(BasicJob.before_enqueue_approve(*test_args_with_hash)).to be_truthy
      expect { BasicJob.before_enqueue_approve(*test_args_with_hash) }.not_to(change { test_args_with_hash })
    end

    it "raises Resque::Job::DontPerform if it is to be approved" do
      expect(BasicJob.before_enqueue_approve(*test_args_without_hash_approve)).to be_falsey
      expect { BasicJob.before_enqueue_approve(*test_args_without_hash_approve) }.not_to(change { test_args_without_hash })
      expect(BasicJob.before_enqueue_approve(*test_args_with_hash_approve)).to be_falsey
      expect { BasicJob.before_enqueue_approve(*test_args_with_hash_approve) }.not_to(change { test_args_with_hash })
    end
  end

  describe "approval methods" do
    let(:pending_job_queue) do
      instance_double(Resque::Plugins::Approve::PendingJobQueue,
                      approve_all: nil,
                      approve_one: nil,
                      approve_num: nil,
                      remove_all:  nil,
                      remove_one:  nil)
    end

    before(:each) do
      allow(Resque::Plugins::Approve::PendingJobQueue).to receive(:new).with("Some_Queue").and_return pending_job_queue
    end

    it "responds to approve" do
      BasicJob.approve

      expect(pending_job_queue).to have_received(:approve_all)
    end

    it "responds to approve_one" do
      BasicJob.approve_one

      expect(pending_job_queue).to have_received(:approve_one)
    end

    it "responds to approve_one" do
      BasicJob.approve_num 12

      expect(pending_job_queue).to have_received(:approve_num).with(12)
    end

    it "responds to remove" do
      BasicJob.remove

      expect(pending_job_queue).to have_received(:remove_all)
    end

    it "responds to remove_one" do
      BasicJob.remove_one

      expect(pending_job_queue).to have_received(:remove_one)
    end
  end
end
