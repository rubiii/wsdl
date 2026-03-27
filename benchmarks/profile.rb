# frozen_string_literal: true

require 'bundler/setup'
require 'fileutils'
require 'stackprof'
require 'wsdl'

FIXTURE_DIR = File.expand_path('../spec/fixtures', __dir__)

# Shared HTTP mock for file-based WSDL loading
class BenchHTTP
  def client = :bench

  def get(url)
    WSDL::HTTP::Response.new(status: 200, body: File.read(url))
  end
end

HTTP = BenchHTTP.new

SMALL_WSDL = File.join(FIXTURE_DIR, 'wsdl/blz_service.wsdl')
LARGE_WSDL = File.join(FIXTURE_DIR, 'wsdl/economic.wsdl')

MODES = {
  'wall' => { mode: :wall, interval: 100, label: 'wall time' },
  'cpu' => { mode: :cpu, interval: 100, label: 'CPU time' },
  'objects' => { mode: :object, interval: 1, label: 'object allocations' }
}.freeze

def run_profile(name)
  config = MODES.fetch(name) { abort "Unknown mode: #{name}. Use: #{MODES.keys.join(', ')}, all" }
  dump = "tmp/stackprof-large-#{name}.dump"

  puts "== Profiling: #{config[:label]} =="
  StackProf.run(mode: config[:mode], out: dump, interval: config[:interval], raw: true) do
    WSDL::Parser.parse(LARGE_WSDL, HTTP)
  end
  puts "Written to #{dump}"
  puts "  bundle exec stackprof #{dump} --text --limit 30"
  puts
end

def run_allocations
  puts '== Object allocation count =='
  GC.start
  GC.disable
  before = GC.stat[:total_allocated_objects]
  WSDL::Parser.parse(LARGE_WSDL, HTTP)
  after = GC.stat[:total_allocated_objects]
  GC.enable
  puts "Objects allocated: #{after - before}"
  puts
end

def run_timing
  puts '== Phase Timing (large WSDL) =='
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  WSDL::Parser.parse(LARGE_WSDL, HTTP)
  t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  puts "Full parse: #{(t1 - t0).round(3)}s"
  puts
end

# --- Main -------------------------------------------------------------------

FileUtils.mkdir_p('tmp')

# Warmup
WSDL::Parser.parse(SMALL_WSDL, HTTP)

puts "Ruby #{RUBY_VERSION} | Nokogiri #{Nokogiri::VERSION}"
puts '-' * 60

mode = ARGV.first || 'all'

run_timing

if mode == 'all'
  MODES.each_key { |m| run_profile(m) }
else
  run_profile(mode)
end

run_allocations
