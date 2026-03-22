# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'yard'

RSpec::Core::RakeTask.new
RuboCop::RakeTask.new
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

# rubocop:disable Metrics/BlockLength
namespace :lint do
  desc 'Check markdown links point to existing files'
  task :links do
    errors = []
    root = File.expand_path(__dir__)
    md_files = Dir.glob([
      File.join(root, '*.md'),               # Top-level markdown files
      File.join(root, 'docs', '**', '*.md')  # Markdown files in /docs
    ])

    md_files.each do |file|
      dir = File.dirname(file)
      File.read(file).scan(/\[(?:[^\]]*)\]\(([^)]+)\)/).flatten.each do |link|
        next if link.start_with?('http://', 'https://', 'mailto:')

        path = link.split('#').first
        next if path.empty?

        target = File.expand_path(path, dir)
        next if File.exist?(target)

        relative = file.sub("#{root}/", '')
        errors << "  #{relative}: #{link}"
      end
    end

    if errors.any?
      abort "Broken markdown links:\n#{errors.join("\n")}"
    else
      puts "All markdown links OK (#{md_files.size} files checked)"
    end
  end
end
# rubocop:enable Metrics/BlockLength

desc 'Run linting'
task lint: %i[rubocop lint:links]

desc 'Run performance benchmarks'
task :benchmark do
  ruby 'benchmarks/run.rb'
end

task ci: %i[lint yard:audit spec]
