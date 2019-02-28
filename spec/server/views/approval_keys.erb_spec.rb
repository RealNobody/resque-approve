# frozen_string_literal: true

require "rails_helper"

RSpec.describe "approval_keys.erb" do
  let(:key_list) { Resque::Plugins::Approve::ApprovalKeyList.new }
  let(:keys) { Array.new(5) { Faker::Lorem.sentence } }
  let!(:jobs) do
    keys.map do |approval_key|
      job = Resque::Plugins::Approve::PendingJob.new(SecureRandom.uuid, class_name: BasicJob, args: [approval_key: approval_key])

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
    let(:cleaner) { Resque::Plugins::Approve::Cleaner }

    before(:each) do
      allow(Resque::Plugins::Approve::ApprovalKeyList).to receive(:new).and_return key_list
    end

    it "should respond to /approve/audit_jobs" do
      expect(cleaner).to receive(:cleanup_jobs).and_call_original

      post "/approve/audit_jobs"

      expect(last_response).to be_redirect
      expect(last_response.header["Location"]).to match(/approve$/)
      expect(Resque).not_to have_received(:enqueue_to)
    end

    it "should respond to /approve/audit_queues" do
      expect(cleaner).to receive(:cleanup_queues).and_call_original

      post "/approve/audit_queues"

      expect(last_response).to be_redirect
      expect(last_response.header["Location"]).to match(/approve$/)
      expect(Resque).not_to have_received(:enqueue_to)
    end

    it "should respond to /approve/approve_all_queues" do
      expect(key_list).to receive(:approve_all).and_call_original

      post "/approve/approve_all_queues"

      expect(last_response).to be_redirect
      expect(last_response.header["Location"]).to match(/approve$/)
      expect(Resque).to have_received(:enqueue_to).exactly(jobs.flatten.count).times
    end

    it "should respond to /approve/delete_all_queues" do
      expect(key_list).to receive(:delete_all).and_call_original

      post "/approve/delete_all_queues"

      expect(last_response).to be_redirect
      expect(last_response.header["Location"]).to match(/approve$/)
      expect(Resque).not_to have_received(:enqueue_to)
    end
  end

  it "should respond to /approve" do
    get "/approve"

    expect(last_response).to be_ok

    expect(last_response.body).to match %r{action="/approve/audit_jobs"}
    expect(last_response.body).to match %r{action="/approve/audit_queues"}
    expect(last_response.body).to match %r{action="/approve/approve_all_queues"}
    expect(last_response.body).to match %r{action="/approve/delete_all_queues"}

    expect(last_response.body).to match %r{&sort=approval_key">(\n *)?Approval Key\n +</a>}
    expect(last_response.body).to match %r{&sort=num_jobs">(\n *)?Pending Jobs\n +</a>}
    expect(last_response.body).to match %r{&sort=first_enqueued">(\n *)?First Enqueued\n +</a>}

    keys.each do |approval_key|
      expect(last_response.body).to match %r{#{approval_key}\n +</a>}
      expect(last_response.body).to match %r{/job_list\?#{{ approval_key: approval_key }.to_param.gsub("+", "\\\\+")}}
    end
  end

  it "pages queues" do
    get "/approve?page_size=2"

    expect(last_response).to be_ok

    expect(last_response.body).to match(%r{href="/approve?.*page_num=2})
    expect(last_response.body).to match(%r{href="/approve?.*page_num=3})
    expect(last_response.body).not_to match(%r{href="/approve?.*page_num=4})
  end
end
