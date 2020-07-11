# frozen_string_literal: true

module Resque
  module Plugins
    module Approve
      # This module adds a new class level perform method that overrides the jobs classes
      # class method perform that is used by Resque.
      #
      # The new overloaded method uses super to perform the original perform functionality
      # but ensures that when the job is complete that it approves the next job in the queue.
      #
      # The reason for this class is to manage the maximum number of jobs that are allowed to
      # run at the same time for a particular job.  When the maximum number of jobs is reached
      # when a job completes, it will approve the next job in the queue automatically.
      module CompressableAutoApproveNext
        def perform_with_auto_approve(*args)
          job          = Resque::Plugins::Approve::PendingJob.new(SecureRandom.uuid, class_name: name, args: args)
          dup_args     = job.uncompressed_args
          del_options  = dup_args.extract_options!.with_indifferent_access
          approval_key = del_options.delete(:approval_key) || job.approve_options[:approval_key]

          dup_args << del_options if del_options.present?

          begin
            perform_without_auto_approve(*dup_args)
          ensure
            Resque::Plugins::Approve::PendingJobQueue.new(approval_key).decrement_running
            Resque::Plugins::Approve.approve_one approval_key
          end
        end

        def self.extended(base)
          class << base
            alias_method :perform_without_auto_approve, :perform
            alias_method :perform, :perform_with_auto_approve
          end
        end
      end
    end
  end
end
