# frozen_string_literal: true

$LOAD_PATH.push File.expand_path("lib", __dir__)

# Maintain your gem's version:
require "resque/plugins/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "resque-approve"
  s.version     = Resque::Plugins::Approve::VERSION
  s.authors     = ["RealNobody"]
  s.email       = ["RealNobody1@cox.net"]
  s.homepage    = "https://github.com/RealNobody"
  s.summary     = "Keeps a list of jobs which require approval to run."
  s.description = "Keeps a list of jobs which require approval to run."
  s.license     = "MIT"

  s.files      = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["spec/**/*"]

  s.add_dependency "redis"
  s.add_dependency "redis-namespace"
  s.add_dependency "resque"

  s.add_development_dependency "activesupport"
  s.add_development_dependency "cornucopia"
  s.add_development_dependency "faker"
  s.add_development_dependency "gem-release"
  s.add_development_dependency "resque-scheduler"
  s.add_development_dependency "rspec-rails", "> 3.9.1"
  s.add_development_dependency "rubocop"
  s.add_development_dependency "simplecov"
  s.add_development_dependency "sinatra"
  s.add_development_dependency "timecop"
end
