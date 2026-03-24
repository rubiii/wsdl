# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'yard'

RSpec::Core::RakeTask.new
RuboCop::RakeTask.new('lint:ruby')
YARD::Rake::YardocTask.new

namespace :yard do
  desc 'Check YARD documentation coverage and warnings'
  task :audit do
    require 'open3'

    flags = %w[stats --list-undoc --fail-on-warning --no-cache --no-save]
    stdout, stderr, status = Open3.capture3('bundle', 'exec', 'yard', *flags)
    output = stdout + stderr
    puts output

    abort 'YARD audit failed: warnings detected' unless status.success?
    abort 'YARD audit failed: not 100% documented' unless output.include?('100.00% documented')
  end
end

namespace :lint do
  desc 'Check markdown links point to existing files'
  task :links do
    require_relative 'scripts/lint_links'
    LintLinks.check
  end

  desc 'Autofix RuboCop offenses (safe and unsafe)'
  task fix: 'lint:ruby:autocorrect_all'
end

desc 'Run linting'
task lint: %i[lint:ruby lint:links]

desc 'Run performance benchmarks'
task :benchmark do
  ruby 'benchmarks/run.rb'
end

task ci: %i[lint yard:audit spec]

task :default do
  system 'rake -T'
end
