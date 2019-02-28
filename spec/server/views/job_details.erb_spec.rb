# frozen_string_literal: true

require "rails_helper"

RSpec.describe "job_details.erb" do
  let(:key) { Faker::Lorem.sentence }
  let(:key_list) { Resque::Plugins::Approve::ApprovalKeyList.new }
  let(:test_args) do
    rand_args = []
    rand_args << Faker::Lorem.sentence
    rand_args << Faker::Lorem.paragraph
    rand_args << SecureRandom.uuid.to_s
    rand_args << rand(0..1_000_000_000_000_000_000_000_000).to_s
    rand_args << rand(0..1_000_000_000_000).seconds.ago.to_s
    rand_args << rand(0..1_000_000_000_000).seconds.from_now.to_s
    rand_args << Array.new(rand(1..5)) { Faker::Lorem.word }
    rand_args << Array.new(rand(1..5)).each_with_object({}) do |_nil_value, sub_hash|
      sub_hash[Faker::Lorem.word] = Faker::Lorem.word
    end

    rand_args = rand_args.sample(rand(3..rand_args.length))

    if [true, false].sample
      options_hash                    = {}
      options_hash[Faker::Lorem.word] = Faker::Lorem.sentence
      options_hash[Faker::Lorem.word] = Faker::Lorem.paragraph
      options_hash[Faker::Lorem.word] = SecureRandom.uuid.to_s
      options_hash[Faker::Lorem.word] = rand(0..1_000_000_000_000_000_000_000_000).to_s
      options_hash[Faker::Lorem.word] = rand(0..1_000_000_000_000).seconds.ago.to_s
      options_hash[Faker::Lorem.word] = rand(0..1_000_000_000_000).seconds.from_now.to_s
      options_hash[Faker::Lorem.word] = Array.new(rand(1..5)) { Faker::Lorem.word }
      options_hash[Faker::Lorem.word] = Array.new(rand(1..5)).
          each_with_object({}) do |_nil_value, sub_hash|
        sub_hash[Faker::Lorem.word] = Faker::Lorem.word
      end

      rand_args << options_hash.slice(*options_hash.keys.sample(rand(5..options_hash.keys.length))).merge(approval_key: key)
    else
      rand_args << { approval_key: key }
    end

    rand_args
  end
  let(:job_id) { SecureRandom.uuid }
  let(:job) do
    new_job = Resque::Plugins::Approve::PendingJob.new(job_id, class_name: BasicJob, args: test_args)

    key_list.add_job(new_job)

    new_job
  end

  include Rack::Test::Methods

  def app
    @app ||= Resque::Server.new
  end

  before(:each) do
    allow(Resque).to receive(:enqueue_to).and_call_original
  end

  it "should respond to /approve/delete_job" do
    post "/approve/delete_job?job_id=#{job.id}"

    expect(last_response).to be_redirect
    expect(last_response.header["Location"]).to match(%r{approve/job_list\?#{{ approval_key: key }.to_param.gsub("+", "\\\\+")}})

    expect(Resque::Plugins::Approve::PendingJob.new(job.id).class_name).to be_blank
    expect(Resque::Plugins::Approve::PendingJobQueue.new(key).num_jobs).to be_zero
    expect(Resque).not_to have_received(:enqueue_to)
  end

  it "should respond to /approve/approve_job" do
    post "/approve/approve_job?job_id=#{job.id}"

    expect(last_response).to be_redirect
    expect(last_response.header["Location"]).to match(%r{approve/job_list\?#{{ approval_key: key }.to_param.gsub("+", "\\\\+")}})

    expect(Resque::Plugins::Approve::PendingJob.new(job.id).class_name).to be_blank
    expect(Resque::Plugins::Approve::PendingJobQueue.new(key).num_jobs).to be_zero
    expect(Resque).to have_received(:enqueue_to)
  end

  it "should respond to /approve/job_details" do
    get "/approve/job_details?job_id=#{job.id}"

    expect(last_response).to be_ok

    expect(last_response.body).to be_include(key)

    expect(last_response.body).to match %r{Approval Keys(\n *)?</a>}
    expect(last_response.body).to match %r{#{key}(\n *)?</a>}

    expect(last_response.body).to match %r{action="/approve/delete_job\?#{{ job_id: job_id }.to_param}"}
    expect(last_response.body).to match %r{action="/approve/approve_job\?#{{ job_id: job_id }.to_param}"}

    expect(last_response.body).to match(%r{Enqueued(\n *)</td>})
    expect(last_response.body).to match(%r{Class(\n *)</td>})
    expect(last_response.body).to match(%r{Params(\n *)</td>})
    expect(last_response.body).to match(%r{Queue(\n *)</td>})
    expect(last_response.body).not_to match(%r{Enqueue After(\n *)</td>})

    expect(last_response.body).to be_include("approve/job_list?#{{ approval_key: key }.to_param}\"")
    expect(last_response.body).to be_include("approve\"")
  end

  it "includes the enqueue after value" do
    test_args.last[:approval_at] = 2.hours.from_now

    get "/approve/job_details?job_id=#{job.id}"

    expect(last_response).to be_ok
    expect(last_response.body).to match(%r{Enqueue After(\n *)</td>})
  end

  it "does not includes the enqueue after value if it is old" do
    test_args.last[:approval_at] = 2.hours.ago

    get "/approve/job_details?job_id=#{job.id}"

    expect(last_response).to be_ok
    expect(last_response.body).not_to match(%r{Enqueue After(\n *)</td>})
  end

  it "shows the parameters for the jobs" do
    get "/approve/job_details?job_id=#{job.id}"

    expect(last_response).to be_ok

    expect(last_response.body).to be_include("".html_safe + job.args.to_yaml)
  end
end
