# frozen_string_literal: true

class MaxActiveJob < BasicJob
  self.max_active_jobs = 10
end
