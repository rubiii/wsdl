# frozen_string_literal: true

require 'timeout'

# Adds a +:with_timeout+ metadata tag that wraps each example in a
# +Timeout.timeout+ call to prevent runaway tests from consuming
# all memory or hanging indefinitely.
#
# Auto-applied to all specs in +spec/property/+ where generative
# tests can pick large WSDL definitions that cause extreme resource
# consumption.
#
# Configure the per-example timeout (in seconds) via +SPEC_TIMEOUT+:
#
#   SPEC_TIMEOUT=60 bundle exec rspec spec/property/
#
# @example Tag a single example or group
#   it 'does something expensive', :with_timeout do
#     # ...
#   end
module SpecTimeout
  DEFAULT_SECONDS = 30

  def self.install!(config)
    config.around(:example, :with_timeout) do |example|
      seconds = Integer(ENV.fetch('SPEC_TIMEOUT', DEFAULT_SECONDS))

      Timeout.timeout(seconds, Timeout::Error, "Test exceeded #{seconds}s timeout: #{example.description}") do
        example.run
      end
    end

    config.define_derived_metadata(file_path: %r{spec/property/}) do |metadata|
      metadata[:with_timeout] = true
    end
  end
end

RSpec.configure do |config|
  SpecTimeout.install!(config)
end
