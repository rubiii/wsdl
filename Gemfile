source 'https://rubygems.org'
gemspec

# profiling
#gem 'method_profiler', require: false
#gem 'ruby-prof',       require: false  # does not work on jruby!

# coverage
gem 'simplecov', require: false
gem 'coveralls', require: false

if RUBY_VERSION >= "3"
  # net-smtp, net-pop and net-imap were removed from ruby standard gems
  gem "net-smtp", require: false
  gem "net-pop", require: false
  gem "net-imap", require: false
  gem "rexml"
end

if RUBY_VERSION >= "3.4"
  # syslog was removed from default gems in Ruby 3.4 (used by logging gem)
  gem "syslog"
  # benchmark will be removed from default gems in Ruby 3.5
  gem "benchmark"
end

# dependencies
#gem 'rubydeps',  require: false  # uses c extensions

# debugging
#gem 'debugger',  require: false

group :development do
  gem 'fuubar'
end
