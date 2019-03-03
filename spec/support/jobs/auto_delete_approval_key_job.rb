# frozen_string_literal: true

class AutoDeleteApprovalKeyJob < BasicJob
  self.auto_delete_approval_key = true
end
