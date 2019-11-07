# frozen_string_literal: true

module Resque
  module Plugins
    module Approve
      # A class representing a queue of Pending jobs.
      #
      # The queue is named with the approval_key for all of the jobs in the queue and contains a list of the jobs.
      class PendingJobQueue
        include Resque::Plugins::Approve::RedisAccess

        attr_reader :approval_key

        def initialize(approval_key)
          @approval_key = approval_key
        end

        def pause
          redis.set(pause_key, true)
          redis.set(paused_count_key, 0)
        end

        def paused?
          redis.get(pause_key)
        end

        def num_ignored
          redis.get(paused_count_key).to_i
        end

        def resume
          redis.del(paused_count_key)
          redis.del(pause_key)
        end

        def delete
          jobs.each(&:delete)
        end

        def remove_job(job)
          redis.lrem(queue_key, 0, job.id)

          remove_approval_key(job)
        end

        def verify_job(job)
          ApprovalKeyList.new.add_key(job.approval_key)

          ids = redis.lrange(queue_key, 0, -1)

          return if ids.include?(job.id)

          redis.lpush(queue_key, job.id)
        end

        def add_job(job)
          redis.rpush(queue_key, job.id)

          job.save!
        end

        def approve_one
          return false if paused_job_skip?

          id = redis.lpop(queue_key)

          enqueue_job(id)
        end

        def approve_num(num_approve)
          num_approve.times { approve_one }
        end

        def approve_all
          true while approve_one
        end

        def pop_job
          return false if paused_job_skip?

          id = redis.rpop(queue_key)

          enqueue_job(id)
        end

        def remove_one
          id = redis.lpop(queue_key)

          delete_job(id)
        end

        def remove_num(num_approve)
          num_approve.times { remove_one }
        end

        def remove_all
          true while remove_one
        end

        def remove_job_pop
          id = redis.rpop(queue_key)

          delete_job(id)
        end

        def paged_jobs(page_num = 1, job_page_size = nil)
          job_page_size ||= 20
          job_page_size = job_page_size.to_i
          job_page_size = 20 if job_page_size < 1
          start         = (page_num - 1) * job_page_size
          start         = 0 if start >= num_jobs || start.negative?

          jobs(start, start + job_page_size - 1)
        end

        def jobs(start = 0, stop = -1)
          redis.lrange(queue_key, start, stop).map { |id| Resque::Plugins::Approve::PendingJob.new(id) }
        end

        def num_jobs
          redis.llen(queue_key)
        end

        def first_enqueued
          jobs(0, 0).first&.queue_time
        end

        private

        def remove_approval_key(job)
          return unless job.class_name.constantize.auto_delete_approval_key

          ApprovalKeyList.new.remove_key(approval_key) if num_jobs.zero?
        end

        def paused_job_skip?
          return false unless paused?

          redis.incr(paused_count_key)

          true
        end

        def enqueue_job(id)
          return false unless id.present?

          Resque::Plugins::Approve::PendingJob.new(id).enqueue_job

          true
        end

        def delete_job(id)
          return false unless id.present?

          Resque::Plugins::Approve::PendingJob.new(id).delete

          true
        end

        def queue_key
          @queue_key ||= "approve.job_queue.#{approval_key}"
        end

        def pause_key
          @pause_key ||= "approve.job_queue.#{approval_key}.paused"
        end

        def paused_count_key
          @paused_count_key ||= "approve.job_queue.#{approval_key}.paused.count"
        end
      end
    end
  end
end
