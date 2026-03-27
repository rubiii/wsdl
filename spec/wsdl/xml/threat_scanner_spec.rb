# frozen_string_literal: true

RSpec.describe WSDL::XML::ThreatScanner do
  describe '#count_open_tags' do
    it 'counts regular open tags' do
      scanner = described_class.new('<a><b><c></c></b></a>')
      expect(scanner.count_open_tags).to eq(3)
    end

    it 'skips closing tags' do
      scanner = described_class.new('</a></b></c>')
      expect(scanner.count_open_tags).to eq(0)
    end

    it 'skips comments' do
      scanner = described_class.new('<!-- comment --><a/>')
      expect(scanner.count_open_tags).to eq(1)
    end

    it 'skips processing instructions' do
      scanner = described_class.new('<?xml version="1.0"?><root/>')
      expect(scanner.count_open_tags).to eq(1)
    end

    it 'counts tags starting with uppercase letters' do
      scanner = described_class.new('<Root><Child/></Root>')
      expect(scanner.count_open_tags).to eq(2)
    end

    it 'ignores tags starting with non-letter characters' do
      scanner = described_class.new('<1invalid><_also>')
      expect(scanner.count_open_tags).to eq(0)
    end

    it 'returns zero for empty string' do
      scanner = described_class.new('')
      expect(scanner.count_open_tags).to eq(0)
    end

    it 'returns zero for plain text' do
      scanner = described_class.new('no tags here')
      expect(scanner.count_open_tags).to eq(0)
    end
  end

  describe '#scan_attribute_threats' do
    it 'returns empty array for normal attributes' do
      scanner = described_class.new('<root attr="value"/>')
      expect(scanner.scan_attribute_threats).to be_empty
    end

    it 'detects a single large attribute value' do
      scanner = described_class.new(%(<root attr="#{'x' * 10_001}"/>))
      expect(scanner.scan_attribute_threats).to include(:large_attribute)
    end

    it 'does not flag an attribute at the threshold' do
      scanner = described_class.new(%(<root attr="#{'x' * 10_000}"/>))
      expect(scanner.scan_attribute_threats).not_to include(:large_attribute)
    end

    it 'detects large cumulative attribute size' do
      attrs = (1..101).map { |i| %(a#{i}="#{'x' * 10_000}") }.join(' ')
      scanner = described_class.new("<root #{attrs}/>")
      expect(scanner.scan_attribute_threats).to include(:large_attributes_total)
    end

    it 'does not flag cumulative size at the threshold' do
      attrs = (1..100).map { |i| %(a#{i}="#{'x' * 10_000}") }.join(' ')
      scanner = described_class.new("<root #{attrs}/>")
      expect(scanner.scan_attribute_threats).not_to include(:large_attributes_total)
    end

    it 'handles single-quoted attribute values' do
      scanner = described_class.new(%(<root attr='#{'x' * 10_001}'/>))
      expect(scanner.scan_attribute_threats).to include(:large_attribute)
    end

    it 'handles whitespace around the equals sign' do
      scanner = described_class.new(%(<root attr= "#{'x' * 10_001}"/>))
      expect(scanner.scan_attribute_threats).to include(:large_attribute)
    end

    it 'returns empty array for empty string' do
      scanner = described_class.new('')
      expect(scanner.scan_attribute_threats).to be_empty
    end

    it 'handles equals signs in text content' do
      scanner = described_class.new('<root>a=b and c=d</root>')
      expect(scanner.scan_attribute_threats).to be_empty
    end

    it 'handles mixed single and double quoted attributes' do
      scanner = described_class.new(%(<root a="one" b='two' c="three"/>))
      expect(scanner.scan_attribute_threats).to be_empty
    end

    it 'handles unclosed quote gracefully' do
      scanner = described_class.new('<root attr="unclosed/>')
      expect(scanner.scan_attribute_threats).to be_empty
    end

    it 'handles tab and carriage return around the equals sign' do
      scanner = described_class.new(%(<root attr\t=\r\n"value"/>))
      expect(scanner.scan_attribute_threats).to be_empty
    end

    it 'measures multiple large attributes independently' do
      large = 'x' * 10_001
      scanner = described_class.new(%(<root a="#{large}" b='#{large}'/>))
      threats = scanner.scan_attribute_threats
      expect(threats.count(:large_attribute)).to eq(2)
    end
  end

  describe '#scan' do
    it 'returns an empty array for safe XML' do
      scanner = described_class.new('<root><child attr="value">text</child></root>')
      expect(scanner.scan).to be_empty
    end

    it 'detects multiple threats in the same document' do
      xml = <<~XML
        <!DOCTYPE foo [
          <!ENTITY xxe SYSTEM "file:///etc/passwd">
        ]>
        <root/>
      XML

      scanner = described_class.new(xml)
      expect(scanner.scan).to include(:doctype, :entity_declaration, :external_reference)
    end

    it 'detects parameter entities' do
      scanner = described_class.new('<!DOCTYPE foo [%param;]><root/>')
      expect(scanner.scan).to include(:parameter_entity)
    end

    it 'detects deep nesting' do
      xml = ('<a>' * 1_001) + ('</a>' * 1_001)
      scanner = described_class.new(xml)
      expect(scanner.scan).to include(:deep_nesting)
    end

    it 'deduplicates threat entries' do
      scanner = described_class.new('<!DOCTYPE foo SYSTEM "a" PUBLIC "b" "c"><root/>')
      expect(scanner.scan.count(:external_reference)).to eq(1)
    end
  end
end
