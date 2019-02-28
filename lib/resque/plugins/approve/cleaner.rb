# frozen_string_literal: true

module Resque
  module Plugins
    module Approve
      # A class for cleaning out all redis values associated with
      class Cleaner
        include RedisAccess

        class << self
          def redis
            @redis ||= Resque::Plugins::Approve::Cleaner.new.redis
          end

          def purge_all
            keys = redis.keys("*")

            return if keys.blank?

            redis.del(*keys)
          end

          def cleanup_jobs
            jobs = redis.keys("approve.pending_job.*")

            jobs.each do |job_key|
              job = Resque::Plugins::Approve::PendingJob.new(job_key[20..-1])

              job.queue.verify_job(job)
            end
          end

          def cleanup_queues
            key_list = Resque::Plugins::Approve::ApprovalKeyList.new

            key_list.queues.each do |pending_job_queue|
              key_list.remove_key(pending_job_queue.approval_key) if pending_job_queue.num_jobs.zero?
            end
          end
        end
      end
    end
  end
end
