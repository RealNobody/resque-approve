# frozen_string_literal: true

require "active_support/concern"
require "active_support/core_ext/numeric/time"

module Resque
  module Plugins
    # Include in a Resque Job to keep allow the hooks to run.
    module Approve
      extend ActiveSupport::Concern

      included do
        self.auto_delete_approval_key = false
      end

      class << self
        def approve(approval_key)
          PendingJobQueue.new(approval_key).approve_all
        end

        def approve_one(approval_key)
          PendingJobQueue.new(approval_key).approve_one
        end

        def approve_num(num_approve, approval_key)
          PendingJobQueue.new(approval_key).approve_num(num_approve)
        end

        def remove(approval_key)
          PendingJobQueue.new(approval_key).remove_all
        end

        def remove_one(approval_key)
          PendingJobQueue.new(approval_key).remove_one
        end
      end

      # The class methods added to the job class that is being enqueued to determine if it should be
      # shunted to the list of pending jobs, or enqueued.
      module ClassMethods
        def auto_delete_approval_key=(value)
          @auto_delete_approval_key = value
        end

        def auto_delete_approval_key
          @auto_delete_approval_key
        end

        # It is possible to run a job immediately using `Resque.push`.  This will bypass the queue and run
        # the job immediately.  This will prevent such a job from enqueuing, and instead pause it for approval
        #
        # The primary reason for this is to prevent the job from receiving the approval parameters it is not
        # supposed to have when actually run/enqueued.
        def before_perform_approve(*args)
          # Check if the job needs to be approved, and if so, do not enqueue it.
          job = PendingJob.new(SecureRandom.uuid, class_name: name, args: args)

          if job.requires_approval?
            ApprovalKeyList.new.add_job(job)

            raise Resque::Job::DontPerform, "The job has not been approved yet."
          else
            true
          end
        end

        # Check if the job needs to be approved, and if so, do not enqueue it.
        def before_enqueue_approve(*args)
          job = PendingJob.new(SecureRandom.uuid, class_name: name, args: args)

          if job.requires_approval?
            ApprovalKeyList.new.add_job(job)
            false
          else
            true
          end
        end
      end
    end
  end
end
