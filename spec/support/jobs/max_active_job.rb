# frozen_string_literal: true

require "resque/plugins/compressible"

class MaxActiveJob < BasicJob
  self.max_active_jobs = 10

  extend Resque::Plugins::Compressible
end
