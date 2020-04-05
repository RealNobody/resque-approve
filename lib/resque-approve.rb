# frozen_string_literal: true

require "resque"
require File.expand_path(File.join("resque", "plugins", "approve", "redis_access"), File.dirname(__FILE__))
require File.expand_path(File.join("resque", "plugins", "approve", "pending_job"), File.dirname(__FILE__))
require File.expand_path(File.join("resque", "plugins", "approve", "pending_job_queue"), File.dirname(__FILE__))
require File.expand_path(File.join("resque", "plugins", "approve", "approval_key_list"), File.dirname(__FILE__))
require File.expand_path(File.join("resque", "plugins", "approve", "cleaner"), File.dirname(__FILE__))
require File.expand_path(File.join("resque", "plugins", "approve", "auto_approve_next"), File.dirname(__FILE__))

require File.expand_path(File.join("resque", "plugins", "approve"), File.dirname(__FILE__))
