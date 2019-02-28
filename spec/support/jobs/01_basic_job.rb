# frozen_string_literal: true

class BasicJob
  include Resque::Plugins::Approve

  def self.queue
    "Some_Queue"
  end

  def self.perform(*args)
    Resque.logger.warn "Args:\n#{Resque.encode(args)}"
  end
end
