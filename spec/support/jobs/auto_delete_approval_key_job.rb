# frozen_string_literal: true

require "resque/plugins/compressible"

class AutoDeleteApprovalKeyJob < BasicJob
  self.auto_delete_approval_key = true

  extend Resque::Plugins::Compressible
end
