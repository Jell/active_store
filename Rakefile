require "bundler/gem_tasks"
# Get your spec rake tasks working in RSpec 2.0

require 'rspec/core/rake_task'

desc "Run specs"
RSpec::Core::RakeTask.new do |t|
  t.pattern = "./spec/**/*_spec.rb" # don't need this, it's default.
  # Put spec opts in a file named .rspec in root
end


RUBIES = %w[jruby-1.6.5 1.9.2-p290]
desc "Run tests with ruby 1.8.7 and 1.9.2"
task :default do
  RUBIES.each do |ruby|
    sh "rvm #{ruby}@active_store rake spec"
  end
end
