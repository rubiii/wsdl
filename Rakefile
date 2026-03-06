# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'yard'

RSpec::Core::RakeTask.new
RuboCop::RakeTask.new
YARD::Rake::YardocTask.new

desc 'Run linting'
task lint: :rubocop

desc 'Run performance benchmarks'
task :benchmark do
  ruby 'benchmarks/run.rb'
end

task ci: %i[lint spec]
