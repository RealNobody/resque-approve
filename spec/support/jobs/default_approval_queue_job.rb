# frozen_string_literal: true

class DefaultApprovalQueue < BasicJob
  self.default_queue_name = "Default Approval Queue"
end
