# frozen_string_literal: true

module Resque
  module Plugins
    module Approve
      # A module to add a `redis` method for a class in this gem that needs redis to get a reids object that is namespaced.
      module RedisAccess
        NAME_SPACE = "Resque::Plugins::Approve::"

        def redis
          @redis ||= Redis::Namespace.new(NAME_SPACE, redis: Resque.redis)
        end
      end
    end
  end
end
