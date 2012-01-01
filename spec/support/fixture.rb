require "nokogiri"

module SpecSupport
  class Fixture

    def initialize(file)
      self.file = file
    end

    attr_accessor :file

    def to_doc
      Nokogiri::XML(to_s)
    end

    def to_hash
      YAML.load(to_s)
    end

    def to_s
      File.read File.expand_path("spec/fixtures/#{file}")
    end

  end

  module FixtureMethods

    def fixture(file)
      Fixture.new(file)
    end

  end
end
