# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'yard'

RSpec::Core::RakeTask.new
RuboCop::RakeTask.new
YARD::Rake::YardocTask.new

desc 'Generate a dependency graph'
task :graph do
  system <<-BASH
    rm -rf graph
    mkdir graph
    GRAPH=true rspec
    mv rubydeps.dump graph
    cd graph
    rubydeps --path_filter='lib/sekken'
    dot -Tsvg rubydeps.dot > rubydeps.svg
    open -a 'Google Chrome' rubydeps.svg
  BASH
end

# CI task
task ci: %i[rubocop spec]
