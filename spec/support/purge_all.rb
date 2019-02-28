# frozen_string_literal: true

RSpec.configure do |configuration|
  configuration.before(:each) do
    Resque::Plugins::Approve::Cleaner.purge_all

    Resque.redis.redis.flushdb
  end

  configuration.after(:each) do
    Resque::Plugins::Approve::Cleaner.purge_all

    Resque.redis.redis.flushdb
  end
end
