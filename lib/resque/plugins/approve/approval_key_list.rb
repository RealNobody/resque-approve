# frozen_string_literal: true

module Resque
  module Plugins
    module Approve
      # A class representing a queue of Pending job_queues.
      #
      # The queue is named with the approval_key for all of the job_queues in the queue and contains a list of the job_queues.
      class ApprovalKeyList
        include Resque::Plugins::Approve::RedisAccess

        def order_param(sort_option, current_sort, current_order)
          current_order ||= "asc"

          if sort_option == current_sort
            current_order == "asc" ? "desc" : "asc"
          else
            "asc"
          end
        end

        def remove_key(key)
          redis.srem(list_key, key)
        end

        def add_key(key)
          redis.sadd(list_key, key)
        end

        def add_job(job)
          add_key(job.approval_key)

          Resque::Plugins::Approve::PendingJobQueue.new(job.approval_key).add_job(job)
        end

        def delete_all
          queues.each do |queue|
            queue.delete
            remove_key(queue.approval_key)
          end

          redis.del(list_key)
        end

        def approve_all
          queues.each(&:approve_all)
        end

        def queues(sort_key = :approval_key,
                   sort_order = "asc",
                   page_num = 1,
                   queue_page_size = 20)
          queue_page_size = queue_page_size.to_i
          queue_page_size = 20 if queue_page_size < 1

          job_queues = sorted_job_queues(sort_key)

          page_start = (page_num - 1) * queue_page_size
          page_start = 0 if page_start > job_queues.length || page_start.negative?

          (sort_order == "desc" ? job_queues.reverse : job_queues)[page_start..(page_start + queue_page_size - 1)]
        end

        def job_queues
          @job_queues ||= queue_keys.map { |approval_key| Resque::Plugins::Approve::PendingJobQueue.new(approval_key) }
        end

        def queue_keys
          @queue_keys ||= redis.smembers(list_key)
        end

        def num_queues
          queue_keys.length
        end

        private

        def list_key
          @list_key ||= "approve.approval_key_list"
        end

        def sorted_job_queues(sort_key)
          job_queues.sort_by do |job_queue|
            approval_key_sort_value(job_queue, sort_key)
          end
        end

        def approval_key_sort_value(job_queue, sort_key)
          case sort_key.to_sym
            when :approval_key,
                :num_jobs
              job_queue.public_send(sort_key)
            when :first_enqueued
              job_queue.public_send(sort_key).to_s
          end
        end
      end
    end
  end
end
