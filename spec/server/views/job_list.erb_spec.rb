# frozen_string_literal: true

require "rails_helper"

RSpec.describe "approval_keys.erb" do
  let(:key_list) { Resque::Plugins::Approve::ApprovalKeyList.new }
  let(:key) { Faker::Lorem.sentence }
  let(:queue) { Resque::Plugins::Approve::PendingJobQueue.new(key) }
  let!(:jobs) do
    Array.new(5) do
      job = Resque::Plugins::Approve::PendingJob.new(SecureRandom.uuid, class_name: BasicJob, args: [approval_key: key])

      key_list.add_job(job)

      job
    end
  end

  include Rack::Test::Methods

  def app
    @app ||= Resque::Server.new
  end

  before(:each) do
    allow(Resque).to receive(:enqueue_to).and_call_original
  end

  context "actions" do
    before(:each) do
      allow(Resque::Plugins::Approve::PendingJobQueue).to receive(:new).and_return queue
    end

    it "should respond to /approve/delete_queue" do
      expect(queue).to receive(:delete).and_call_original

      post "/approve/delete_queue?#{{ approval_key: key }.to_param}"

      expect(last_response).to be_redirect
      expect(last_response.header["Location"]).to match(/approve$/)
      expect(Resque).not_to have_received(:enqueue_to)
    end

    it "should respond to /approve/delete_one_queue" do
      expect(queue).to receive(:remove_one).and_call_original

      post "/approve/delete_one_queue?#{{ approval_key: key }.to_param}"

      expect(last_response).to be_redirect
      expect(last_response.header["Location"]).to match(%r{approve/job_list\?#{{ approval_key: key }.to_param.gsub("+", "\\\\+")}$})
      expect(Resque).not_to have_received(:enqueue_to)
    end

    it "should respond to /approve/approve_queue" do
      expect(queue).to receive(:approve_all).and_call_original

      post "/approve/approve_queue?#{{ approval_key: key }.to_param}"

      expect(last_response).to be_redirect
      expect(last_response.header["Location"]).to match(%r{approve/job_list\?#{{ approval_key: key }.to_param.gsub("+", "\\\\+")}$})
      expect(Resque).to have_received(:enqueue_to).exactly(jobs.flatten.count).times
    end

    it "should respond to /approve/approve_one_queue" do
      expect(queue).to receive(:approve_one).and_call_original

      post "/approve/approve_one_queue?#{{ approval_key: key }.to_param}"

      expect(last_response).to be_redirect
      expect(last_response.header["Location"]).to match(%r{approve/job_list\?#{{ approval_key: key }.to_param.gsub("+", "\\\\+")}$})
      expect(Resque).to have_received(:enqueue_to)
    end
  end

  it "should respond to /approve/job_list" do
    get "/approve/job_list?#{{ approval_key: key }.to_param}"

    expect(last_response).to be_ok

    expect(last_response.body).to be_include(key)

    expect(last_response.body).to match %r{Approval Keys(\n *)?</a>}

    expect(last_response.body).to match %r{action="/approve/delete_queue\?#{{ approval_key: key }.to_param.gsub("+", "\\\\+")}"}
    expect(last_response.body).to match %r{action="/approve/delete_one_queue\?#{{ approval_key: key }.to_param.gsub("+", "\\\\+")}"}
    expect(last_response.body).to match %r{action="/approve/approve_queue\?#{{ approval_key: key }.to_param.gsub("+", "\\\\+")}"}
    expect(last_response.body).to match %r{action="/approve/approve_one_queue\?#{{ approval_key: key }.to_param.gsub("+", "\\\\+")}"}

    expect(last_response.body).to match %r{Class</th>}
    expect(last_response.body).to match %r{Enqueued</th>}
    expect(last_response.body).to match %r{Parameters</th>}
    expect(last_response.body).to match %r{Options</th>}

    jobs.each do |job|
      expect(last_response.body).to match %r{/job_details\?#{{ job_id: job.id }.to_param}}
    end
  end

  it "pages jobs" do
    get "/approve/job_list?#{{ approval_key: key }.to_param}&page_size=2"

    expect(last_response).to be_ok

    expect(last_response.body).to match(%r{href="/approve/job_list?.*page_num=2})
    expect(last_response.body).to match(%r{href="/approve/job_list?.*page_num=3})
    expect(last_response.body).not_to match(%r{href="/approve/job_list?.*page_num=4})
  end
end
