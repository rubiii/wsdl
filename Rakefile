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

namespace :specifications do
  desc 'Check if local specification documents are up to date'
  task :check do
    require_relative 'scripts/specifications'
    abort unless Specifications.check
  end

  desc 'Download and convert all specification documents'
  task :update do
    require_relative 'scripts/specifications'
    Specifications.update
  end

  desc 'Re-download and reconvert all specification documents'
  task :reconvert do
    require_relative 'scripts/specifications'
    Specifications.update(force: true)
  end
end

desc 'Run performance benchmarks'
task :benchmark do
  ruby 'benchmarks/run.rb'
end

namespace :benchmark do
  desc 'Run performance specs (allocation budgets + timing)'
  task :specs do
    sh 'bundle exec rspec spec/performance/ --format documentation'
  end
end

namespace :profile do
  modes = {
    wall: 'Wall-time', cpu: 'CPU',
    objects: 'Object allocation', all: 'All (wall + cpu + objects)'
  }
  modes.each do |mode, label|
    desc "#{label} profile of large WSDL parse"
    task(mode) { ruby "benchmarks/profile.rb #{mode}" }
  end

  desc 'Print a StackProf dump report'
  task :report, [:dump] do |_t, args|
    abort 'Usage: rake profile:report[path/to/dump]' unless args[:dump]
    sh 'bundle', 'exec', 'stackprof', args[:dump], '--text', '--limit', '30'
  end

  desc 'Drill into a specific method in a StackProf dump'
  task :method, [:dump, :method_name] do |_t, args|
    abort 'Usage: rake profile:method[path/to/dump,ClassName#method]' unless args[:dump] && args[:method_name]
    sh 'bundle', 'exec', 'stackprof', args[:dump], '--method', args[:method_name]
  end
end

desc 'Run all checks (lint + docs + tests with coverage)'
task :ci do
  ENV['COVERAGE'] = '1'
  %w[lint yard:audit spec].each { |t| Rake::Task[t].invoke }
end

task :default do
  system 'rake -T'
end
