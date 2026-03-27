# frozen_string_literal: true

module SpecSupport
  # Measures total Ruby object allocations inside a block.
  #
  # Deterministic: not affected by wall-clock timing jitter, making it
  # safe for CI assertions. Disables GC for the measurement window so
  # collections don't skew the count.
  #
  # @yield the block whose allocations to measure
  # @return [Integer] number of objects allocated during the block
  #
  # @example
  #   allocs = count_allocations { WSDL::Parser.parse(wsdl, http) }
  #   expect(allocs).to be < 1_000_000
  def count_allocations
    GC.start
    GC.disable
    before = GC.stat(:total_allocated_objects)
    yield
    GC.stat(:total_allocated_objects) - before
  ensure
    GC.enable
  end
end
