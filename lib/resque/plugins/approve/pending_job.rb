# frozen_string_literal: true

module Resque
  module Plugins
    module Approve
      # rubocop:disable Metrics/ClassLength

      # A class representing a Pending job that is awaiting approval.
      #
      # Each job has the following values:
      #   id          - The approve gem ID used to store and restore the job in Redis
      #   class_name  - The name of the job class to be enqueued
      #   args        - The arguments for the job to be enqueued
      #
      #   requires_approval - If a class defines a default approval queue (similar to defining
      #                       the queue for Resque), then instead of passing `approval_key: "key name"` in the
      #                       parameters, you would pass `requires_approval: true`.  This way the key name
      #                       appears only in the class and not scattered through the code.
      #   approval_key      - The approval key for the pending job that will be used to release/approve the job.
      #                       This will default to nil.
      #   approval_queue    - The queue that the pending job will be enqueued into.
      #                       This will default to the queue for the job.
      #   approval_at       - The time when the job is to be enqueued.
      #                       This will call `enqueue_at` to enqueue the job, so this option will only work
      #                       properly if you use the `resque-scheduler` gem.
      #
      #                       When using resque-scheduler, there are two ways to delay enqueue a job
      #                       and how you do this depends on your use case.
      #
      #                       Resque.enqueue YourJob, params, approval_key: "your key", approval_at: time
      #                       This will enqueue the job for approval, which will pause the job until it is approved.
      #                       Once approved, the job will delay enqueue for time, and will execute immediately or at
      #                       that time depending on if the time has passed.
      #
      #                       This is the recommended method to use as it will not run the job early, and it will allow
      #                       you to release it without knowing if it is still delayed or not.
      #
      #                       You can also do:
      #                       Resque.enqueue_at time, YourJob, params, approval_key: "your key"
      #                       This will delay enqueue the job - because it has not been enqueued yet, the job
      #                       cannot be releaed until the time has passed and the job is actually enqueued.
      #                       Any time after that point, it can be released.  Releasing the key before this
      #                       time has no effect on this job.
      class PendingJob
        include Resque::Plugins::Approve::RedisAccess
        include Comparable

        attr_reader :id

        def initialize(id = SecureRandom.uuid, class_name: nil, args: [])
          @approve_options = {}
          @id              = id
          @class_name      = class_name.is_a?(String) ? class_name : class_name&.name
          self.args        = args
        end

        def <=>(other)
          return nil unless other.is_a?(Resque::Plugins::Approve::PendingJob)

          id <=> other.id
        end

        def class_name
          @class_name ||= stored_values[:class_name]
        end

        def uncompressed_args
          decompress_args(args)
        end

        def args
          @args = if @args.present?
                    @args
                  else
                    Array.wrap(decode_args(stored_values[:args]))
                  end
        end

        def args=(value)
          if value.nil?
            @args = []
          else
            @args = Array.wrap(value).dup

            extract_approve_options
          end
        end

        def approve_options
          @approve_options = if @approve_options.present?
                               @approve_options
                             else
                               (decode_args(stored_values[:approve_options])&.first || {}).with_indifferent_access
                             end
        end

        def approval_keys?
          @approval_keys ||= (approve_options.key?(:approval_key) || approve_options[:requires_approval])
        end

        def requires_approval?
          @requires_approval ||= approval_keys? && too_many_running?
        end

        def approval_key
          @approval_key ||= approve_options[:approval_key]
        end

        def approval_queue
          @approval_queue ||= approve_options[:approval_queue] || Resque.queue_from_class(klass)
        end

        def max_active_jobs?
          return @max_active_jobs if defined?(@max_active_jobs)

          @max_active_jobs = max_active_jobs.positive?
        end

        def max_active_jobs
          max_val = ((klass.respond_to?(:max_active_jobs) && klass.max_active_jobs) ||
              (klass.instance_variable_defined?(:@max_active_jobs) && klass.instance_variable_get(:@max_active_jobs)))

          return -1 if max_val.blank?

          max_val.to_i
        end

        def approval_at
          @approval_at ||= approve_options[:approval_at]&.to_time
        end

        def queue_time
          @queue_time ||= stored_values[:queue_time]&.to_time
        end

        def enqueue_job
          return_value = if approval_at.present?
                           Resque.enqueue_at_with_queue approval_queue, approval_at, klass, *compressed_args(args)
                         else
                           Resque.enqueue_to approval_queue, klass, *compressed_args(args)
                         end

          delete

          return_value
        end

        # rubocop:disable Metrics/AbcSize
        def save!
          redis.hset(job_key, "class_name", class_name)
          redis.hset(job_key, "args", encode_args(*args))
          redis.hset(job_key, "approve_options", encode_args(approve_options))
          redis.hset(job_key, "queue_time", Time.now)
        end

        # rubocop:enable Metrics/AbcSize

        def delete
          # Make sure the job is loaded into memory so we can use it even though we are going to delete it.
          stored_values

          redis.del(job_key)

          return if class_name.blank?

          queue.remove_job(self)
        end

        def queue
          @queue ||= Resque::Plugins::Approve::PendingJobQueue.new(approval_key)
        end

        def max_jobs_perform_args(args)
          return compressed_max_jobs_perform_args(args) if compressed?(args)

          return unless args.last.is_a?(Hash)

          remove_options = args[-1]

          %i[approval_queue approval_at requires_approval].each do |key|
            remove_options.delete(key)
            remove_options.delete(key.to_s)
          end
        end

        def compressed?(basic_args)
          return false unless compressable?

          described_class.compressed?(basic_args)
        end

        def compressable?
          !described_class.blank? &&
              described_class.singleton_class.included_modules.map(&:name).include?("Resque::Plugins::Compressible")
        end

        private

        def compressed_max_jobs_perform_args(args)
          decompressed = decompress_args(args)

          max_jobs_perform_args(decompressed)
          decompressed = compressed_args(decompressed)[0]

          compress_arg            = args[0]
          compress_arg[:payload]  = decompressed[:payload] if compress_arg.key?(:payload)
          compress_arg["payload"] = decompressed[:payload] if compress_arg.key?("payload")
        end

        def klass
          @klass ||= class_name.constantize
        end

        def job_key
          @job_key ||= "approve.pending_job.#{id}"
        end

        def stored_values
          @stored_values ||= (redis.hgetall(job_key) || {}).with_indifferent_access
        end

        def extract_approve_options
          extract_args = uncompressed_args

          return if extract_args.blank? || !extract_args[-1].is_a?(Hash)

          self.approve_options = extract_args.pop.with_indifferent_access

          options = slice_approval_options

          extract_args << options.to_hash if options.present?
          @args = compressed_args(extract_args)
        end

        # rubocop:disable Layout/SpaceAroundOperators
        def slice_approval_options
          options                        = approve_options.slice!(:approval_key, :approval_queue, :approval_at, :requires_approval)
          approve_options[:approval_key] ||= klass.default_queue_name if approve_options[:requires_approval]

          options_approval_key(options)

          options
        end

        # rubocop:enable Layout/SpaceAroundOperators

        def encode_args(*args)
          Resque.encode(args)
        end

        def decode_args(args_string)
          return if args_string.blank?

          Resque.decode(args_string)
        end

        def approve_options=(value)
          @approve_options = (value&.dup || {}).with_indifferent_access
        end

        def too_many_running?
          return true if queue.paused?
          return true unless max_active_jobs?
          return @too_many_running if defined?(@too_many_running)

          num_running = queue.increment_running
          max_jobs    = max_active_jobs

          queue.decrement_running if num_running > max_jobs
          @too_many_running = num_running > max_jobs
        end

        def options_approval_key(options)
          return unless max_active_jobs?
          return if options.key?(:approval_key)

          if compressable?
            unless klass.singleton_class.included_modules.include?(Resque::Plugins::Approve::CompressableAutoApproveNext)
              klass.extend Resque::Plugins::Approve::CompressableAutoApproveNext
            end
          else
            klass.include Resque::Plugins::Approve::AutoApproveNext unless klass.included_modules.include?(Resque::Plugins::Approve::AutoApproveNext)
          end

          options[:approval_key] = approve_options.fetch(:approval_key) { klass.default_queue_name }
        end

        def described_class
          return if class_name.blank?

          class_name.constantize
        rescue StandardError
          nil
        end

        def compressed_args(compress_args)
          return compress_args unless compressable?
          return compress_args if described_class.compressed?(compress_args)

          [{ :resque_compressed => true, :payload => described_class.compressed_args(compress_args) }]
        end

        def decompress_args(basic_args)
          return basic_args unless compressable?
          return basic_args unless described_class.compressed?(basic_args)

          described_class.uncompressed_args(basic_args.first[:payload] || basic_args.first["payload"])
        end
      end

      # rubocop:enable Metrics/ClassLength
    end
  end
end
