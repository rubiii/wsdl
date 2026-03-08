# frozen_string_literal: true

source 'https://rubygems.org'
gemspec

# syslog was removed from default gems in Ruby 3.4
gem 'syslog' if RUBY_VERSION >= '3.4'

# benchmark was removed from default gems in Ruby 4.0 (silence warning on 3.4+)
gem 'benchmark' if RUBY_VERSION >= '3.4'

# irb was removed from default gems in Ruby 4.0 (required by yard's legacy parser)
gem 'irb' if RUBY_VERSION >= '4.0'

group :development do
  gem 'benchmark-ips', '~> 2.14', require: false
  gem 'equivalent-xml', '~> 0.6'
  gem 'mutant-rspec', '~> 0.12', require: false
  gem 'rake', '~> 13.3'
  gem 'rantly', '~> 2.0', require: false
  gem 'redcarpet', require: false
  gem 'rspec', '~> 3'
  gem 'rspec-github', '~> 2.4', require: false
  gem 'rubocop', require: false
  gem 'rubocop-rake', require: false
  gem 'rubocop-rspec', require: false
  gem 'rubocop-yard', require: false
  gem 'simplecov', '~> 0.22', require: false
  gem 'webmock', '~> 3.24', require: false
  gem 'yard', require: false
  gem 'yard-markdown-relative-links', require: false
end
