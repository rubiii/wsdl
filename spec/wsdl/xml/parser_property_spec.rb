# frozen_string_literal: true

# rubocop:disable Style/MultilineBlockChain

require 'rantly'
require 'rantly/rspec_extensions'

RSpec.describe WSDL::XML::Parser do
  describe 'property-based security' do
    let(:trial_count) { Integer(ENV.fetch('PROPERTY_TRIALS', 100)) }

    describe 'invariant: DOCTYPE is always rejected regardless of casing or position' do
      it 'rejects randomly-cased DOCTYPE declarations' do
        property_of {
          doctype = 'DOCTYPE'.chars.map { |c| choose(c.upcase, c.downcase) }.join
          "<!#{doctype} foo><root/>"
        }.check(trial_count) do |xml|
          expect {
            described_class.parse(xml)
          }.to raise_error(WSDL::XMLSecurityError, /DOCTYPE/)
        end
      end

      it 'rejects DOCTYPE preceded by random whitespace and XML declaration' do
        property_of {
          spaces = ' ' * range(0, 20)
          doctype = 'DOCTYPE'.chars.map { |c| choose(c.upcase, c.downcase) }.join
          "<?xml version=\"1.0\"?>#{spaces}<!#{doctype} foo><root/>"
        }.check(trial_count) do |xml|
          expect {
            described_class.parse(xml)
          }.to raise_error(WSDL::XMLSecurityError, /DOCTYPE/)
        end
      end

      it 'rejects DOCTYPE in relaxed mode too' do
        property_of {
          doctype = 'DOCTYPE'.chars.map { |c| choose(c.upcase, c.downcase) }.join
          "<!#{doctype} foo><root/>"
        }.check(trial_count) do |xml|
          expect {
            described_class.parse_relaxed(xml)
          }.to raise_error(WSDL::XMLSecurityError, /DOCTYPE/)
        end
      end

      it 'rejects DOCTYPE via parse_untrusted' do
        property_of {
          doctype = 'DOCTYPE'.chars.map { |c| choose(c.upcase, c.downcase) }.join
          "<!#{doctype} foo><root/>"
        }.check(trial_count) do |xml|
          expect {
            described_class.parse_untrusted(xml)
          }.to raise_error(WSDL::XMLSecurityError, /DOCTYPE/)
        end
      end

      it 'rejects DOCTYPE via parse_with_logging' do
        property_of {
          doctype = 'DOCTYPE'.chars.map { |c| choose(c.upcase, c.downcase) }.join
          "<!#{doctype} foo><root/>"
        }.check(trial_count) do |xml|
          expect {
            described_class.parse_with_logging(xml)
          }.to raise_error(WSDL::XMLSecurityError, /DOCTYPE/)
        end
      end
    end

    describe 'invariant: well-formed safe XML always parses successfully' do
      it 'parses random well-formed XML without errors' do
        property_of {
          tag = choose(*('a'..'z').to_a) + sized(range(0, 8)) { string(:alpha) }
          text = sized(range(0, 50)) { string(:alpha) }
          "<#{tag}>#{text}</#{tag}>"
        }.check(trial_count) do |xml|
          doc = described_class.parse(xml)
          expect(doc).to be_a(Nokogiri::XML::Document)
          expect(doc.root).not_to be_nil
        end
      end

      it 'parses nested random XML' do
        property_of {
          outer = choose(*('a'..'z').to_a) + sized(range(0, 5)) { string(:alpha) }
          inner = choose(*('a'..'z').to_a) + sized(range(0, 5)) { string(:alpha) }
          text = sized(range(0, 30)) { string(:alpha) }
          "<#{outer}><#{inner}>#{text}</#{inner}></#{outer}>"
        }.check(trial_count) do |xml|
          doc = described_class.parse(xml)
          expect(doc).to be_a(Nokogiri::XML::Document)
          expect(doc.root.element_children.length).to eq(1)
        end
      end

      it 'parses XML with random attributes' do
        property_of {
          tag = choose(*('a'..'z').to_a) + sized(range(0, 5)) { string(:alpha) }
          attr_name = choose(*('a'..'z').to_a) + sized(range(0, 5)) { string(:alpha) }
          attr_val = sized(range(0, 20)) { string(:alpha) }
          "<#{tag} #{attr_name}=\"#{attr_val}\"/>"
        }.check(trial_count) do |xml|
          doc = described_class.parse(xml)
          expect(doc).to be_a(Nokogiri::XML::Document)
        end
      end

      it 'parses SOAP-like XML with random namespaces' do
        property_of {
          prefix = choose(*('a'..'z').to_a) + sized(range(0, 4)) { string(:alpha) }
          ns_uri = "http://#{sized(range(3, 12)) { string(:alpha) }}.com"
          tag = sized(range(1, 10)) { string(:alpha) }
          body = sized(range(1, 8)) { string(:alpha) }
          text = sized(range(0, 30)) { string(:alpha) }
          "<#{prefix}:#{tag} xmlns:#{prefix}=\"#{ns_uri}\">" \
            "<#{prefix}:#{body}>#{text}</#{prefix}:#{body}>" \
            "</#{prefix}:#{tag}>"
        }.check(trial_count) do |xml|
          doc = described_class.parse(xml)
          expect(doc).to be_a(Nokogiri::XML::Document)
          expect(doc.root).not_to be_nil
          expect(doc.root.namespace).not_to be_nil
        end
      end
    end

    describe 'invariant: detect_threats and parse agree on DOCTYPE' do
      it 'parse rejects whenever detect_threats finds :doctype' do
        property_of {
          doctype = 'DOCTYPE'.chars.map { |c| choose(c.upcase, c.downcase) }.join
          "<!#{doctype} foo><root/>"
        }.check(trial_count) do |xml|
          threats = described_class.detect_threats(xml)
          expect(threats).to include(:doctype)

          expect {
            described_class.parse(xml)
          }.to raise_error(WSDL::XMLSecurityError)
        end
      end

      it 'parse succeeds when detect_threats finds no threats' do
        property_of {
          tag = choose(*('a'..'z').to_a) + sized(range(0, 8)) { string(:alpha) }
          text = sized(range(0, 50)) { string(:alpha) }
          "<#{tag}>#{text}</#{tag}>"
        }.check(trial_count) do |xml|
          threats = described_class.detect_threats(xml)
          expect(threats).to be_empty

          doc = described_class.parse(xml)
          expect(doc).to be_a(Nokogiri::XML::Document)
        end
      end
    end

    describe 'invariant: security keywords in content do not block parsing' do
      it 'does not reject element text containing security keywords' do
        property_of {
          keyword = choose('DOCTYPE', 'ENTITY', 'SYSTEM', 'PUBLIC')
          tag = choose(*('a'..'z').to_a) + sized(range(0, 5)) { string(:alpha) }
          "<#{tag}>The keyword #{keyword} appears in text</#{tag}>"
        }.check(trial_count) do |xml|
          doc = described_class.parse(xml)
          expect(doc).to be_a(Nokogiri::XML::Document)
          expect(doc.root.text).to include('keyword')
        end
      end

      it 'does not reject attribute values containing security keywords' do
        property_of {
          keyword = choose('DOCTYPE', 'ENTITY', 'SYSTEM', 'PUBLIC')
          tag = choose(*('a'..'z').to_a) + sized(range(0, 5)) { string(:alpha) }
          "<#{tag} note=\"contains #{keyword} word\"/>"
        }.check(trial_count) do |xml|
          doc = described_class.parse(xml)
          expect(doc).to be_a(Nokogiri::XML::Document)
        end
      end
    end

    describe 'invariant: random input never causes a hang or crash' do
      def random_bytes
        len = Rantly { range(1, 500) }
        Array.new(len) { rand(0..255).chr(Encoding::BINARY) }.join
      end

      it 'always raises or returns a document for random byte sequences (binary)' do
        property_of {
          len = range(1, 500)
          Array.new(len) { range(0, 255).chr(Encoding::BINARY) }.join
        }.check(trial_count) do |garbage|
          result = begin
            described_class.parse(garbage)
          rescue WSDL::XMLSecurityError, Nokogiri::XML::SyntaxError, ArgumentError,
                 EncodingError => e
            e
          end
          expect(result).to be_a(Nokogiri::XML::Document).or be_a(Exception)
        end
      end

      it 'always raises or returns a document for random byte sequences (forced UTF-8)' do
        property_of {
          len = range(1, 500)
          Array.new(len) { range(0, 255).chr(Encoding::BINARY) }.join.force_encoding('UTF-8')
        }.check(trial_count) do |garbage|
          result = begin
            described_class.parse(garbage)
          rescue WSDL::XMLSecurityError, Nokogiri::XML::SyntaxError, ArgumentError,
                 EncodingError => e
            e
          end
          expect(result).to be_a(Nokogiri::XML::Document).or be_a(Exception)
        end
      end

      it 'always raises or returns a document in relaxed mode' do
        property_of {
          len = range(1, 500)
          Array.new(len) { range(0, 255).chr(Encoding::BINARY) }.join
        }.check(trial_count) do |garbage|
          result = begin
            described_class.parse_relaxed(garbage)
          rescue WSDL::XMLSecurityError, Nokogiri::XML::SyntaxError, ArgumentError,
                 EncodingError => e
            e
          end
          expect(result).to be_a(Nokogiri::XML::Document).or be_a(Exception)
        end
      end

      it 'detect_threats never raises for any input (binary)' do
        property_of {
          len = range(1, 1000)
          Array.new(len) { range(0, 255).chr(Encoding::BINARY) }.join
        }.check(trial_count) do |garbage|
          result = described_class.detect_threats(garbage)
          expect(result).to be_an(Array)
        end
      end

      it 'detect_threats never raises for any input (forced UTF-8)' do
        property_of {
          len = range(1, 1000)
          Array.new(len) { range(0, 255).chr(Encoding::BINARY) }.join.force_encoding('UTF-8')
        }.check(trial_count) do |garbage|
          result = described_class.detect_threats(garbage)
          expect(result).to be_an(Array)
        end
      end
    end

    describe 'invariant: XXE payload variations are always blocked' do
      it 'blocks XXE with random entity names and file paths' do
        property_of {
          entity_name = choose(*('a'..'z').to_a) + sized(range(1, 10)) { string(:alpha) }
          segments = Array.new(range(1, 3)) { sized(range(1, 8)) { string(:alpha) } }
          path = "/#{segments.join('/')}"
          <<~XML
            <!DOCTYPE foo [
              <!ENTITY #{entity_name} SYSTEM "file://#{path}">
            ]>
            <root>&#{entity_name};</root>
          XML
        }.check(trial_count) do |xml|
          threats = described_class.detect_threats(xml)
          expect(threats).to include(:doctype)
          expect(threats).to include(:entity_declaration)
          expect(threats).to include(:external_reference)

          expect {
            described_class.parse(xml)
          }.to raise_error(WSDL::XMLSecurityError, /DOCTYPE/)
        end
      end

      it 'blocks parameter entity injection variants' do
        property_of {
          entity_name = choose(*('a'..'z').to_a) + sized(range(1, 8)) { string(:alpha) }
          host = sized(range(3, 15)) { string(:alpha) }
          path = sized(range(1, 8)) { string(:alpha) }
          <<~XML
            <!DOCTYPE foo [
              <!ENTITY % #{entity_name} SYSTEM "http://#{host}.com/#{path}">
              %#{entity_name};
            ]>
            <root/>
          XML
        }.check(trial_count) do |xml|
          threats = described_class.detect_threats(xml)
          expect(threats).to include(:doctype)
          expect(threats).to include(:parameter_entity)

          expect {
            described_class.parse(xml)
          }.to raise_error(WSDL::XMLSecurityError, /DOCTYPE/)
        end
      end
    end
  end
end

# rubocop:enable Style/MultilineBlockChain
