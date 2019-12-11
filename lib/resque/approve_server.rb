# frozen_string_literal: true

require "resque"
require "resque/server"
require "resque-approve"
require "action_view/helpers/output_safety_helper"
require "action_view/helpers/capture_helper"
require "action_view/helpers/date_helper"

# rubocop:disable Metrics/ModuleLength

module Resque
  # Extends Resque Web Based UI.
  # Structure has been borrowed from ResqueHistory.
  module ApproveServer
    include ActionView::Helpers::DateHelper

    class << self
      def erb_path(filename)
        File.join(File.dirname(__FILE__), "server", "views", filename)
      end

      def public_path(filename)
        File.join(File.dirname(__FILE__), "server", "public", filename)
      end

      def included(base)
        add_page_views(base)
        add_button_callbacks(base)
        add_static_files(base)
      end

      private

      def add_page_views(base)
        approval_keys(base)
        job_list(base)
        job_details(base)
      end

      def approval_keys(base)
        approval_key_params(base)

        base.class_eval do
          get "/approve" do
            set_approval_key_params

            erb File.read(Resque::ApproveServer.erb_path("approval_keys.erb"))
          end
        end
      end

      def approval_key_params(base)
        base.class_eval do
          def set_approval_key_params
            @sort_by    = params[:sort] || "approval_key"
            @sort_order = params[:order] || "desc"
            @page_num   = (params[:page_num] || 1).to_i
            @page_size  = (params[:page_size] || 20).to_i
          end
        end
      end

      def job_list(base)
        job_list_params(base)

        base.class_eval do
          get "/approve/job_list" do
            set_job_list_params_params

            erb File.read(Resque::ApproveServer.erb_path("job_list.erb"))
          end
        end
      end

      def job_list_params(base)
        base.class_eval do
          def set_job_list_params_params
            @approval_key = params[:approval_key]
            @page_num     = (params[:page_num] || 1).to_i
            @page_size    = (params[:page_size] || 20).to_i
          end
        end
      end

      def job_details(base)
        base.class_eval do
          get "/approve/job_details" do
            @job_id = params[:job_id]

            erb File.read(Resque::ApproveServer.erb_path("job_details.erb"))
          end
        end
      end

      def add_static_files(base)
        base.class_eval do
          get %r{/approve/public/([a-z_]+\.[a-z]+)} do
            send_file Resque::ApproveServer.public_path(params[:captures]&.first)
          end
        end
      end

      def add_button_callbacks(base)
        audit_jobs(base)
        audit_queues(base)
        delete_all_queues(base)
        approve_all_queues(base)
        delete_queue(base)
        delete_one_queue(base)
        approve_queue(base)
        approve_one_queue(base)
        pause_queue(base)
        resume_queue(base)
        delete_job(base)
        approve_job(base)
      end

      def audit_jobs(base)
        base.class_eval do
          post "/approve/audit_jobs" do
            Resque::Plugins::Approve::Cleaner.cleanup_jobs

            redirect u("approve")
          end
        end
      end

      def audit_queues(base)
        base.class_eval do
          post "/approve/audit_queues" do
            Resque::Plugins::Approve::Cleaner.cleanup_queues

            redirect u("approve")
          end
        end
      end

      def delete_all_queues(base)
        base.class_eval do
          post "/approve/delete_all_queues" do
            Resque::Plugins::Approve::ApprovalKeyList.new.delete_all

            redirect u("approve")
          end
        end
      end

      def approve_all_queues(base)
        base.class_eval do
          post "/approve/approve_all_queues" do
            Resque::Plugins::Approve::ApprovalKeyList.new.approve_all

            redirect u("approve")
          end
        end
      end

      def delete_queue(base)
        base.class_eval do
          post "/approve/delete_queue" do
            Resque::Plugins::Approve::PendingJobQueue.new(params[:approval_key]).delete
            Resque::Plugins::Approve::ApprovalKeyList.new.remove_key(params[:approval_key])

            redirect u("approve")
          end
        end
      end

      def delete_one_queue(base)
        base.class_eval do
          post "/approve/delete_one_queue" do
            Resque::Plugins::Approve::PendingJobQueue.new(params[:approval_key]).remove_one

            redirect u("approve/job_list?#{{ approval_key: params[:approval_key] }.to_param}")
          end
        end
      end

      def approve_queue(base)
        base.class_eval do
          post "/approve/approve_queue" do
            Resque::Plugins::Approve::PendingJobQueue.new(params[:approval_key]).approve_all

            redirect u("approve/job_list?#{{ approval_key: params[:approval_key] }.to_param}")
          end
        end
      end

      def approve_one_queue(base)
        base.class_eval do
          post "/approve/approve_one_queue" do
            Resque::Plugins::Approve::PendingJobQueue.new(params[:approval_key]).approve_one

            redirect u("approve/job_list?#{{ approval_key: params[:approval_key] }.to_param}")
          end
        end
      end

      def pause_queue(base)
        base.class_eval do
          post "/approve/pause" do
            Resque::Plugins::Approve::PendingJobQueue.new(params[:approval_key]).pause

            redirect u("approve/job_list?#{{ approval_key: params[:approval_key] }.to_param}")
          end
        end
      end

      def resume_queue(base)
        base.class_eval do
          post "/approve/resume" do
            Resque::Plugins::Approve::PendingJobQueue.new(params[:approval_key]).resume

            redirect u("approve/job_list?#{{ approval_key: params[:approval_key] }.to_param}")
          end
        end
      end

      def delete_job(base)
        base.class_eval do
          post "/approve/delete_job" do
            job = Resque::Plugins::Approve::PendingJob.new(params[:job_id])

            job.approval_key
            job.delete

            redirect u("approve/job_list?#{{ approval_key: job.approval_key }.to_param}")
          end
        end
      end

      def approve_job(base)
        base.class_eval do
          post "/approve/approve_job" do
            job = Resque::Plugins::Approve::PendingJob.new(params[:job_id])

            job.enqueue_job

            redirect u("approve/job_list?#{{ approval_key: job.approval_key }.to_param}")
          end
        end
      end
    end

    Resque::Server.tabs << "Approve"
  end
end

Resque::Server.class_eval do
  include Resque::ApproveServer
end

# rubocop:enable Metrics/ModuleLength
