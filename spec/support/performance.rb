# frozen_string_literal: true

# Adds a +:performance+ metadata tag for specs in +spec/performance/+.
#
# Performance specs run as part of the normal test suite. They include
# deterministic allocation-budget tests and timing tests with generous
# thresholds. Use +rake benchmark:specs+ to run them in isolation with
# documentation format.
#
# Individual examples that measure wall time can be tagged +:timing+.
# If a timing test ever becomes flaky on CI, exclude it with
# +--tag ~timing+ as a targeted fix.
#
# @example Tag a timing-sensitive example
#   it 'parses within acceptable time', :timing do
#     # ...
#   end
module SpecPerformance
  def self.install!(config)
    config.define_derived_metadata(file_path: %r{spec/performance/}) do |metadata|
      metadata[:performance] = true
    end
  end
end

RSpec.configure do |config|
  SpecPerformance.install!(config)
end
