# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resque::Plugins::Approve::ApprovalKeyList do
  let(:key_list) { Resque::Plugins::Approve::ApprovalKeyList.new }
  let!(:key) { Faker::Lorem.sentence }
  let(:job) { Resque::Plugins::Approve::PendingJob.new SecureRandom.uuid, class_name: BasicJob, args: [approval_key: key] }
  let(:job_queue) { Resque::Plugins::Approve::PendingJobQueue.new(key) }
  let(:multiple_queues) { Array.new(3) { Faker::Lorem.sentence } }
  let(:multiple_jobs) do
    index = 0
    multiple_queues.map do |approval_key|
      Array.new(4) do
        job = Resque::Plugins::Approve::PendingJob.new(SecureRandom.uuid, class_name: BasicJob, args: [index, approval_key: approval_key])

        index += 1
        key_list.add_job(job)

        job
      end
    end
  end

  describe "#order_param" do
    it "returns asc for any column other than the current one" do
      expect(key_list.order_param("sort_option",
                                  "current_sort",
                                  %w[asc desc].sample)).to eq "asc"
    end

    it "returns desc for the current column if it is asc" do
      expect(key_list.order_param("sort_option", "sort_option", "asc")).to eq "desc"
    end

    it "returns asc for the current column if it is desc" do
      expect(key_list.order_param("sort_option", "sort_option", "desc")).to eq "asc"
    end
  end

  describe "remove_key" do
    it "removes the key if it is in the list" do
      key_list.add_key key
      10.times do
        key_list.add_key(Faker::Lorem.sentence)
      end

      expect { key_list.remove_key key }.to(change { Resque::Plugins::Approve::ApprovalKeyList.new.num_queues }.by(-1))
    end

    it "does nothing if it is not in the list" do
      10.times do
        key_list.add_key(Faker::Lorem.sentence)
      end

      expect { key_list.remove_key key }.not_to(change { Resque::Plugins::Approve::ApprovalKeyList.new.num_queues })
    end
  end

  describe "add_key" do
    it "adds the key if it is not in the list" do
      10.times do
        key_list.add_key(Faker::Lorem.sentence)
      end

      expect { key_list.add_key key }.to(change { Resque::Plugins::Approve::ApprovalKeyList.new.num_queues }.by(1))
    end

    it "does nothing if it is in the list" do
      key_list.add_key key
      10.times do
        key_list.add_key(Faker::Lorem.sentence)
      end

      expect { key_list.add_key key }.not_to(change { Resque::Plugins::Approve::ApprovalKeyList.new.num_queues })
    end
  end

  describe "add_job" do
    it "adds the key if it is not in the list" do
      10.times do
        key_list.add_key(Faker::Lorem.sentence)
      end

      expect { key_list.add_job job }.to(change { Resque::Plugins::Approve::ApprovalKeyList.new.num_queues }.by(1))
    end

    it "does not add the key if it is in the list" do
      key_list.add_key key
      10.times do
        key_list.add_key(Faker::Lorem.sentence)
      end

      expect { key_list.add_job job }.not_to(change { Resque::Plugins::Approve::ApprovalKeyList.new.num_queues })
    end

    it "adds the job to the queue if it isn't already there" do
      10.times do
        key_list.add_key(Faker::Lorem.sentence)
      end

      key_list.add_job job

      expect(job_queue.jobs.last.id).to eq job.id
      expect(job_queue.jobs.last).to eq job
    end
  end

  describe "delete_all" do
    before(:each) do
      multiple_jobs
    end

    it "deletes all jobs for all queues" do
      key_list.delete_all

      multiple_jobs.flatten.each do |job|
        expect(Resque::Plugins::Approve::PendingJob.new(job.id).class_name).to be_blank
      end
    end

    it "deletes all queues" do
      queues = key_list.queues

      key_list.delete_all

      queues.each do |queue|
        expect(queue.num_jobs).to be_zero
      end
    end

    it "deletes all keys" do
      key_list.delete_all

      expect(Resque::Plugins::Approve::ApprovalKeyList.new.num_queues).to be_zero
    end
  end

  describe "approve_all" do
    before(:each) do
      multiple_jobs

      allow(Resque).to receive(:enqueue_to).and_call_original
    end

    it "approves all jobs for all queues" do
      key_list.approve_all

      index = 0
      multiple_jobs.flatten.each do |job|
        expect(Resque::Plugins::Approve::PendingJob.new(job.id).class_name).to be_blank
        expect(Resque).to have_received(:enqueue_to).with "Some_Queue", BasicJob, index

        index += 1
      end
    end

    it "approves all queues" do
      queues = key_list.queues

      key_list.approve_all

      queues.each do |queue|
        expect(queue.num_jobs).to be_zero
      end
    end

    it "does not delete any keys" do
      key_list.approve_all

      expect(Resque::Plugins::Approve::ApprovalKeyList.new.num_queues).to eq 3
    end
  end

  describe "queues" do
    let(:sorted_queue_names) { Array.new(30) { |index| "#{index.to_s.rjust(3, "0")} - #{Faker::Lorem.sentence}" } }
    let(:sorted_age) { Array.new(30) { |index| sorted_queue_names[ages.find_index(index)] }.reverse }
    let(:sorted_counts) { Array.new(30) { |index| sorted_queue_names[counts.find_index(index)] } }
    let(:ages) { Array.new(30) { |index| index }.sample(100) }
    let(:counts) { Array.new(30) { |index| index }.sample(100) }
    let!(:jobs) do
      index = 0

      sorted_queue_names.map do |approval_key|
        Timecop.freeze(ages[index].hours.ago) do
          Array.new(1 + counts[index]) do
            job = Resque::Plugins::Approve::PendingJob.new(SecureRandom.uuid, class_name: BasicJob, args: [approval_key: approval_key])

            key_list.add_job(job)

            job
          end
        end

        index += 1
      end
    end

    RSpec.shared_examples("pages queues") do
      it "defaults to return the first 20 queues ascending" do
        expect(key_list.queues(sort_key).map(&:approval_key)).to eq sorted_values[0..19]
      end

      it "does not allow negative page sizes" do
        expect(key_list.queues(sort_key, 0, 0).map(&:approval_key)).to eq sorted_values[0..19]
      end

      it "pages ascending" do
        expect(key_list.queues(sort_key, "asc", 4, 3).map(&:approval_key)).
            to eq sorted_values[9..11]
      end

      it "sorts descending" do
        expect(key_list.queues(sort_key, "desc").map(&:approval_key)).
            to eq sorted_values.reverse[0..19]
      end

      it "pages descending" do
        expect(key_list.queues(sort_key, "desc", 4, 3).map(&:approval_key)).
            to eq sorted_values.reverse[9..11]
      end

      it "does not do negative pages" do
        expect(key_list.queues(sort_key, "desc", -4, 3).map(&:approval_key)).
            to eq sorted_values.reverse[0..2]
      end

      it "does not do to large pages" do
        expect(key_list.queues(sort_key, "desc", 400, 3).map(&:approval_key)).
            to eq sorted_values.reverse[0..2]
      end
    end

    describe "approval_key" do
      let(:sort_key) { :approval_key }
      let(:sorted_values) { sorted_queue_names }

      it_behaves_like "pages queues"
    end

    describe "num_jobs" do
      let(:sort_key) { :num_jobs }
      let(:sorted_values) { sorted_counts }

      it_behaves_like "pages queues"
    end

    describe "first_enqueued" do
      let(:sort_key) { :first_enqueued }
      let(:sorted_values) { sorted_age }

      it_behaves_like "pages queues"
    end
  end

  describe "job_queues" do
    let(:sorted_queue_names) { Array.new(30) { |index| "#{index.to_s.rjust(3, "0")} - #{Faker::Lorem.sentence}" } }
    let!(:jobs) do
      sorted_queue_names.map do |approval_key|
        job = Resque::Plugins::Approve::PendingJob.new(SecureRandom.uuid, class_name: BasicJob, args: [approval_key: approval_key])

        key_list.add_job(job)

        job
      end
    end

    it "returns all queues unsorted" do
      expect(key_list.job_queues.map(&:approval_key).sort).to eq sorted_queue_names
    end
  end

  describe "num_queues" do
    let(:sorted_queue_names) { Array.new(30) { |index| "#{index.to_s.rjust(3, "0")} - #{Faker::Lorem.sentence}" } }
    let!(:jobs) do
      sorted_queue_names.map do |approval_key|
        job = Resque::Plugins::Approve::PendingJob.new(SecureRandom.uuid, class_name: BasicJob, args: [approval_key: approval_key])

        key_list.add_job(job)

        job
      end
    end

    it "returns the total number of queues" do
      expect(key_list.num_queues).to eq 30
    end
  end
end
