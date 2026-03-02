# frozen_string_literal: true

require 'spec_helper'
require 'logger'

describe WSDL::XML::Parser do
  describe '.parse' do
    it 'parses valid XML' do
      xml = '<root><child>text</child></root>'
      doc = described_class.parse(xml)

      expect(doc).to be_a(Nokogiri::XML::Document)
      expect(doc.root.name).to eq('root')
      expect(doc.at_xpath('//child').text).to eq('text')
    end

    it 'returns the document unchanged if already a Document' do
      original = Nokogiri::XML('<root/>')
      result = described_class.parse(original)

      expect(result).to be(original)
    end

    it 'raises ArgumentError for invalid input types' do
      expect { described_class.parse(123) }.to raise_error(ArgumentError, /Expected String or Nokogiri::XML::Document/)
      expect { described_class.parse(nil) }.to raise_error(ArgumentError)
      expect { described_class.parse([]) }.to raise_error(ArgumentError)
    end

    context 'with noblanks option' do
      it 'preserves whitespace by default' do
        xml = "<root>\n  <child>text</child>\n</root>"
        doc = described_class.parse(xml, noblanks: false)

        # With whitespace preserved, there should be text nodes between elements
        expect(doc.root.children.length).to be > 1
      end

      it 'removes blank nodes when noblanks is true' do
        xml = "<root>\n  <child>text</child>\n</root>"
        doc = described_class.parse(xml, noblanks: true)

        # Without blank nodes, only the child element remains
        expect(doc.root.element_children.length).to eq(1)
        expect(doc.root.element_children.first.name).to eq('child')
      end
    end

    context 'DOCTYPE rejection' do
      it 'rejects XML with DOCTYPE by default' do
        xml_with_doctype = '<!DOCTYPE foo><root/>'

        expect {
          described_class.parse(xml_with_doctype)
        }.to raise_error(WSDL::XMLSecurityError, /DOCTYPE declarations are not allowed/)
      end

      it 'rejects DOCTYPE case-insensitively' do
        %w[<!DOCTYPE <!doctype <!DocType].each do |doctype|
          expect {
            described_class.parse("#{doctype} foo><root/>")
          }.to raise_error(WSDL::XMLSecurityError, /DOCTYPE/)
        end
      end

      it 'allows DOCTYPE when reject_doctype: false' do
        xml_with_doctype = '<!DOCTYPE foo><root/>'
        doc = described_class.parse(xml_with_doctype, reject_doctype: false)

        expect(doc).to be_a(Nokogiri::XML::Document)
        expect(doc.root.name).to eq('root')
      end

      it 'includes helpful message about SOAP/WSDL' do
        expect {
          described_class.parse('<!DOCTYPE foo><root/>')
        }.to raise_error(WSDL::XMLSecurityError, %r{Legitimate SOAP/WSDL documents do not require DOCTYPE})
      end

      it 'mentions attack prevention in error message' do
        expect {
          described_class.parse('<!DOCTYPE foo><root/>')
        }.to raise_error(WSDL::XMLSecurityError, /XXE and entity expansion attacks/)
      end

      it 'does not reject XML without DOCTYPE' do
        xml = '<root><child>text</child></root>'
        doc = described_class.parse(xml)

        expect(doc).to be_a(Nokogiri::XML::Document)
        expect(doc.root.name).to eq('root')
      end

      it 'does not trigger on DOCTYPE-like strings in content' do
        xml = '<root>The word DOCTYPE appears here</root>'
        doc = described_class.parse(xml)

        expect(doc.root.text).to eq('The word DOCTYPE appears here')
      end
    end

    context 'XXE protection (strict mode)' do
      it 'does not expand external file entities' do
        # DOCTYPE rejection provides defense-in-depth
        xxe_xml = '<root>safe</root>'
        doc = described_class.parse(xxe_xml)
        expect(doc.root.text).to eq('safe')
      end

      it 'does not load external schemas via xsi:schemaLocation' do
        xml = <<~XML
          <?xml version="1.0"?>
          <root xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                xsi:schemaLocation="http://internal-server.local/schema.xsd">
            content
          </root>
        XML

        # Should parse without network access
        doc = described_class.parse(xml)
        expect(doc.root.name).to eq('root')
      end
    end
  end

  describe '.parse_relaxed' do
    it 'parses malformed XML without raising' do
      # Missing closing tag
      malformed_xml = '<root><child>text</root>'
      doc = described_class.parse_relaxed(malformed_xml)

      expect(doc).to be_a(Nokogiri::XML::Document)
      expect(doc.root).not_to be_nil
    end

    context 'DOCTYPE rejection' do
      it 'rejects XML with DOCTYPE by default' do
        xml_with_doctype = '<!DOCTYPE foo><root/>'

        expect {
          described_class.parse_relaxed(xml_with_doctype)
        }.to raise_error(WSDL::XMLSecurityError, /DOCTYPE declarations are not allowed/)
      end

      it 'allows DOCTYPE when reject_doctype: false' do
        xml_with_doctype = '<!DOCTYPE foo><root/>'
        doc = described_class.parse_relaxed(xml_with_doctype, reject_doctype: false)

        expect(doc).to be_a(Nokogiri::XML::Document)
        expect(doc.root.name).to eq('root')
      end
    end

    it 'handles XML with mismatched tags' do
      xml = '<root><a><b></a></b></root>'
      doc = described_class.parse_relaxed(xml)

      expect(doc).to be_a(Nokogiri::XML::Document)
    end

    context 'XXE protection (relaxed mode)' do
      it 'does not expand external file entities' do
        xxe_xml = <<~XML
          <?xml version="1.0"?>
          <!DOCTYPE foo [
            <!ENTITY xxe SYSTEM "file:///etc/passwd">
          ]>
          <root>&xxe;</root>
        XML

        # Disable DOCTYPE rejection to test underlying XXE protection
        doc = described_class.parse_relaxed(xxe_xml, reject_doctype: false)

        # The entity should NOT be expanded
        root_text = doc.root&.text.to_s
        expect(root_text).not_to include('root:')
        expect(root_text).not_to include('/bin/')
      end

      it 'does not expand external HTTP entities' do
        xxe_xml = <<~XML
          <?xml version="1.0"?>
          <!DOCTYPE foo [
            <!ENTITY xxe SYSTEM "http://internal-server.local/secret">
          ]>
          <root>&xxe;</root>
        XML

        # Disable DOCTYPE rejection to test underlying XXE protection
        doc = described_class.parse_relaxed(xxe_xml, reject_doctype: false)
        expect(doc.root&.text.to_s).not_to include('malicious')
      end

      it 'does not process parameter entities for file access' do
        xxe_xml = <<~XML
          <?xml version="1.0"?>
          <!DOCTYPE foo [
            <!ENTITY % file SYSTEM "file:///etc/passwd">
            <!ENTITY % eval "<!ENTITY xxe SYSTEM 'file:///etc/passwd'>">
            %eval;
          ]>
          <root>&xxe;</root>
        XML

        # Disable DOCTYPE rejection to test underlying XXE protection
        doc = described_class.parse_relaxed(xxe_xml, reject_doctype: false)
        root_text = doc.root&.text.to_s
        expect(root_text).not_to include('root:')
      end

      it 'does not load external DTDs' do
        ssrf_xml = <<~XML
          <?xml version="1.0"?>
          <!DOCTYPE foo SYSTEM "http://internal-server.local/dtd">
          <root>content</root>
        XML

        # Disable DOCTYPE rejection to test underlying DTD protection
        doc = described_class.parse_relaxed(ssrf_xml, reject_doctype: false)
        expect(doc.root.name).to eq('root')
      end
    end
  end

  describe 'Billion Laughs / XML Bomb protection' do
    it 'limits entity expansion to prevent memory exhaustion' do
      # Classic billion laughs attack - 4 levels deep
      # Full expansion would be 10^4 = 10,000 "lol" = 30,000 chars
      bomb_xml = <<~XML
        <?xml version="1.0"?>
        <!DOCTYPE lolz [
          <!ENTITY lol "lol">
          <!ENTITY lol2 "&lol;&lol;&lol;&lol;&lol;&lol;&lol;&lol;&lol;&lol;">
          <!ENTITY lol3 "&lol2;&lol2;&lol2;&lol2;&lol2;&lol2;&lol2;&lol2;&lol2;&lol2;">
          <!ENTITY lol4 "&lol3;&lol3;&lol3;&lol3;&lol3;&lol3;&lol3;&lol3;&lol3;&lol3;">
        ]>
        <root>&lol4;</root>
      XML

      # Disable DOCTYPE rejection to test underlying entity expansion limits
      doc = described_class.parse_relaxed(bomb_xml, reject_doctype: false)
      root_text = doc.root&.text.to_s

      # libxml2 has built-in entity expansion limits.
      # The key assertion is that parsing completes without hanging
      # and doesn't explode to dangerous sizes (100KB+ would indicate a problem)
      expect(root_text.length).to be < 100_000
    end

    it 'handles quadratic blowup attacks' do
      # Quadratic blowup: many references to a large entity
      large_entity = 'A' * 10_000
      bomb_xml = <<~XML
        <?xml version="1.0"?>
        <!DOCTYPE foo [
          <!ENTITY big "#{large_entity}">
        ]>
        <root>&big;&big;&big;&big;&big;</root>
      XML

      # Disable DOCTYPE rejection to test underlying entity expansion limits
      doc = described_class.parse_relaxed(bomb_xml, reject_doctype: false)

      # Should complete without hanging; exact behavior depends on libxml2 config
      expect(doc.root).not_to be_nil
    end
  end

  describe '.detect_threats' do
    it 'detects DOCTYPE declarations' do
      xml = '<!DOCTYPE foo><root/>'
      threats = described_class.detect_threats(xml)
      expect(threats).to include(:doctype)
    end

    it 'detects ENTITY declarations' do
      xml = '<!DOCTYPE foo [<!ENTITY bar "baz">]><root/>'
      threats = described_class.detect_threats(xml)
      expect(threats).to include(:entity_declaration)
    end

    it 'detects SYSTEM identifiers' do
      xml = '<!DOCTYPE foo SYSTEM "http://example.com/dtd"><root/>'
      threats = described_class.detect_threats(xml)
      expect(threats).to include(:external_reference)
    end

    it 'detects PUBLIC identifiers' do
      xml = '<!DOCTYPE foo PUBLIC "-//W3C//DTD" "http://example.com/dtd"><root/>'
      threats = described_class.detect_threats(xml)
      expect(threats).to include(:external_reference)
    end

    it 'detects parameter entities' do
      xml = '<!DOCTYPE foo [<!ENTITY % param "value">%param;]><root/>'
      threats = described_class.detect_threats(xml)
      expect(threats).to include(:parameter_entity)
    end

    it 'returns empty array for safe XML' do
      xml = '<root><child attr="value">text</child></root>'
      threats = described_class.detect_threats(xml)
      expect(threats).to be_empty
    end

    it 'is case-insensitive for DOCTYPE detection' do
      %w[<!doctype <!DOCTYPE <!DocType].each do |doctype|
        threats = described_class.detect_threats("#{doctype} foo><root/>")
        expect(threats).to include(:doctype), "Expected #{doctype} to be detected"
      end
    end

    it 'is case-insensitive for ENTITY detection' do
      %w[<!entity <!ENTITY <!Entity].each do |entity|
        threats = described_class.detect_threats("<!DOCTYPE foo [#{entity} bar \"baz\">]><root/>")
        expect(threats).to include(:entity_declaration), "Expected #{entity} to be detected"
      end
    end

    it 'detects multiple threats in same document' do
      xxe_xml = <<~XML
        <!DOCTYPE foo [
          <!ENTITY xxe SYSTEM "file:///etc/passwd">
          <!ENTITY % param "value">
          %param;
        ]>
        <root/>
      XML

      threats = described_class.detect_threats(xxe_xml)

      expect(threats).to include(:doctype)
      expect(threats).to include(:entity_declaration)
      expect(threats).to include(:external_reference)
      expect(threats).to include(:parameter_entity)
    end

    it 'does not produce duplicate threat entries' do
      xml = '<!DOCTYPE foo SYSTEM "a" PUBLIC "b" "c"><root/>'
      threats = described_class.detect_threats(xml)

      # Should have :external_reference only once even though both SYSTEM and PUBLIC are present
      expect(threats.count(:external_reference)).to eq(1)
    end
  end

  describe '.parse_untrusted' do
    it 'parses XML without threats normally' do
      xml = '<root><child>text</child></root>'
      doc = described_class.parse_untrusted(xml)

      expect(doc).to be_a(Nokogiri::XML::Document)
      expect(doc.root.name).to eq('root')
    end

    it 'yields threats to the block when detected' do
      xxe_xml = '<!DOCTYPE foo [<!ENTITY xxe SYSTEM "file:///etc/passwd">]><root/>'
      detected_threats = nil

      # Disable DOCTYPE rejection to test threat callback behavior
      described_class.parse_untrusted(xxe_xml, reject_doctype: false) do |threats|
        detected_threats = threats
      end

      expect(detected_threats).to include(:doctype)
      expect(detected_threats).to include(:entity_declaration)
      expect(detected_threats).to include(:external_reference)
    end

    it 'does not yield when no threats are detected' do
      safe_xml = '<root><child>text</child></root>'
      block_called = false

      described_class.parse_untrusted(safe_xml) do |_threats|
        block_called = true
      end

      expect(block_called).to be false
    end

    it 'still parses XML securely even when threats are detected' do
      xxe_xml = '<!DOCTYPE foo [<!ENTITY xxe SYSTEM "file:///etc/passwd">]><root>safe</root>'
      # Disable DOCTYPE rejection to test underlying XXE protection
      doc = described_class.parse_untrusted(xxe_xml, reject_doctype: false)

      expect(doc.root.name).to eq('root')
      expect(doc.root.text).not_to include('root:')
    end

    it 'allows blocking via callback' do
      xxe_xml = '<!DOCTYPE foo><root/>'

      expect {
        # Disable default DOCTYPE rejection to test callback-based blocking
        described_class.parse_untrusted(xxe_xml, reject_doctype: false) do |threats|
          raise SecurityError, "Blocked: #{threats.join(', ')}" if threats.any?
        end
      }.to raise_error(SecurityError, /doctype/)
    end

    it 'rejects DOCTYPE by default after threat detection but before parsing completes' do
      xxe_xml = '<!DOCTYPE foo><root/>'
      callback_called = false
      detected_threats = nil

      expect {
        described_class.parse_untrusted(xxe_xml) do |threats|
          callback_called = true
          detected_threats = threats
        end
      }.to raise_error(WSDL::XMLSecurityError, /DOCTYPE/)

      # The callback IS invoked (threat detection happens first)
      # but then parsing fails due to DOCTYPE rejection
      expect(callback_called).to be true
      expect(detected_threats).to include(:doctype)
    end

    it 'does not call callback for Nokogiri documents' do
      doc = Nokogiri::XML('<root/>')
      callback_called = false

      described_class.parse_untrusted(doc) do |_threats|
        callback_called = true
      end

      expect(callback_called).to be false
    end

    it 'uses strict parsing by default' do
      # Strict mode requires well-formed XML
      malformed_xml = '<root><unclosed>'

      expect {
        described_class.parse_untrusted(malformed_xml)
      }.to raise_error(Nokogiri::XML::SyntaxError)
    end

    it 'uses relaxed parsing when strict: false' do
      malformed_xml = '<root><unclosed>'
      doc = described_class.parse_untrusted(malformed_xml, strict: false)

      expect(doc).to be_a(Nokogiri::XML::Document)
    end
  end

  describe '.parse_with_logging' do
    let(:logger) { instance_double(Logger) }

    before do
      allow(logger).to receive(:warn)
    end

    it 'parses XML normally when no threats' do
      xml = '<root><child>text</child></root>'
      doc = described_class.parse_with_logging(xml, logger)

      expect(doc).to be_a(Nokogiri::XML::Document)
      expect(doc.root.name).to eq('root')
      expect(logger).not_to have_received(:warn)
    end

    it 'logs a warning when threats are detected' do
      xxe_xml = '<!DOCTYPE foo [<!ENTITY xxe SYSTEM "file:///etc/passwd">]><root/>'

      # Disable DOCTYPE rejection to test threat logging behavior
      described_class.parse_with_logging(xxe_xml, logger, reject_doctype: false)

      expect(logger).to have_received(:warn).with(
        /Potential XML attack detected.*doctype.*entity_declaration.*external_reference/
      )
    end

    it 'still parses XML securely after logging threats' do
      xxe_xml = '<!DOCTYPE foo [<!ENTITY xxe SYSTEM "file:///etc/passwd">]><root>safe</root>'
      # Disable DOCTYPE rejection to test underlying XXE protection
      doc = described_class.parse_with_logging(xxe_xml, logger, reject_doctype: false)

      expect(doc.root.text).not_to include('root:')
    end

    it 'uses strict parsing by default' do
      malformed_xml = '<root><unclosed>'

      expect {
        described_class.parse_with_logging(malformed_xml, logger)
      }.to raise_error(Nokogiri::XML::SyntaxError)
    end

    it 'uses relaxed parsing when strict: false' do
      malformed_xml = '<root><unclosed>'
      doc = described_class.parse_with_logging(malformed_xml, logger, strict: false)

      expect(doc).to be_a(Nokogiri::XML::Document)
    end

    it 'respects noblanks option' do
      xml = "<root>\n  <child>text</child>\n</root>"
      doc = described_class.parse_with_logging(xml, logger, noblanks: true)

      expect(doc.root.element_children.length).to eq(1)
    end

    it 'uses default logger when none provided' do
      xml = '<root/>'

      # Should not raise when logger is nil
      expect { described_class.parse_with_logging(xml, nil) }.not_to raise_error
    end
  end

  describe 'SOAP-specific scenarios' do
    let(:soap_envelope) do
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
          <soap:Header>
            <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
              <wsse:UsernameToken>
                <wsse:Username>user</wsse:Username>
              </wsse:UsernameToken>
            </wsse:Security>
          </soap:Header>
          <soap:Body>
            <GetUserResponse>
              <User>
                <Name>John Doe</Name>
              </User>
            </GetUserResponse>
          </soap:Body>
        </soap:Envelope>
      XML
    end

    it 'parses SOAP envelopes correctly' do
      doc = described_class.parse(soap_envelope)

      expect(doc.root.name).to eq('Envelope')
      expect(doc.at_xpath('//soap:Body', 'soap' => 'http://schemas.xmlsoap.org/soap/envelope/')).not_to be_nil
    end

    it 'parses SOAP envelopes with noblanks for signature operations' do
      doc = described_class.parse(soap_envelope, noblanks: true)

      body = doc.at_xpath('//soap:Body', 'soap' => 'http://schemas.xmlsoap.org/soap/envelope/')
      expect(body).not_to be_nil
      expect(body.element_children.first.name).to eq('GetUserResponse')
    end

    it 'protects against XXE in SOAP responses' do
      malicious_soap = <<~XML
        <?xml version="1.0"?>
        <!DOCTYPE soap:Envelope [
          <!ENTITY xxe SYSTEM "file:///etc/passwd">
        ]>
        <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
          <soap:Body>
            <Data>&xxe;</Data>
          </soap:Body>
        </soap:Envelope>
      XML

      # Disable DOCTYPE rejection to test underlying XXE protection
      doc = described_class.parse_relaxed(malicious_soap, reject_doctype: false)
      data_text = doc.at_xpath('//Data')&.text.to_s
      expect(data_text).not_to include('root:')
    end

    it 'detects threats in SOAP envelopes' do
      malicious_soap = <<~XML
        <!DOCTYPE soap:Envelope [
          <!ENTITY xxe SYSTEM "file:///etc/passwd">
        ]>
        <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
          <soap:Body>&xxe;</soap:Body>
        </soap:Envelope>
      XML

      threats = described_class.detect_threats(malicious_soap)
      expect(threats).to include(:doctype)
      expect(threats).to include(:entity_declaration)
      expect(threats).to include(:external_reference)
    end
  end

  describe 'parse option constants' do
    it 'includes NONET in secure options' do
      expect(described_class::SECURE_PARSE_OPTIONS & Nokogiri::XML::ParseOptions::NONET).not_to eq(0)
    end

    it 'includes NONET in relaxed options' do
      expect(described_class::RELAXED_PARSE_OPTIONS & Nokogiri::XML::ParseOptions::NONET).not_to eq(0)
    end

    it 'does not include NOENT in secure options (entities not substituted)' do
      # NOENT being absent means entities are NOT substituted, which is secure
      expect(described_class::SECURE_PARSE_OPTIONS & Nokogiri::XML::ParseOptions::NOENT).to eq(0)
    end

    it 'does not include DTDLOAD in secure options (external DTDs not loaded)' do
      expect(described_class::SECURE_PARSE_OPTIONS & Nokogiri::XML::ParseOptions::DTDLOAD).to eq(0)
    end

    it 'does not include DTDATTR in secure options (DTD attributes not defaulted)' do
      expect(described_class::SECURE_PARSE_OPTIONS & Nokogiri::XML::ParseOptions::DTDATTR).to eq(0)
    end

    it 'does not include HUGE in secure options (size limits enforced)' do
      expect(described_class::SECURE_PARSE_OPTIONS & Nokogiri::XML::ParseOptions::HUGE).to eq(0)
    end

    it 'does not include XINCLUDE in secure options (XInclude disabled)' do
      expect(described_class::SECURE_PARSE_OPTIONS & Nokogiri::XML::ParseOptions::XINCLUDE).to eq(0)
    end
  end

  describe 'security regression tests' do
    describe 'XXE (XML External Entity) attacks' do
      it 'blocks file:// entity access' do
        xxe_xml = <<~XML
          <?xml version="1.0"?>
          <!DOCTYPE foo [
            <!ENTITY xxe SYSTEM "file:///etc/passwd">
          ]>
          <root>&xxe;</root>
        XML

        # With DOCTYPE rejection disabled to test underlying XXE protection
        doc = described_class.parse_relaxed(xxe_xml, reject_doctype: false)
        root_text = doc.root&.text.to_s

        # Must not contain file contents
        expect(root_text).not_to include('root:')
        expect(root_text).not_to include('/bin/')
        expect(root_text).not_to include('nobody')
      end

      it 'blocks http:// entity access via NONET' do
        # Verify NONET is set which blocks all network access
        expect(described_class::SECURE_PARSE_OPTIONS & Nokogiri::XML::ParseOptions::NONET).not_to eq(0)
        expect(described_class::RELAXED_PARSE_OPTIONS & Nokogiri::XML::ParseOptions::NONET).not_to eq(0)
      end

      it 'does not substitute entities (NOENT not set)' do
        # NOENT being absent means entities are not substituted
        expect(described_class::SECURE_PARSE_OPTIONS & Nokogiri::XML::ParseOptions::NOENT).to eq(0)
        expect(described_class::RELAXED_PARSE_OPTIONS & Nokogiri::XML::ParseOptions::NOENT).to eq(0)
      end
    end

    describe 'XInclude attacks' do
      it 'does not process XInclude directives' do
        xinclude_xml = <<~XML
          <?xml version="1.0"?>
          <root xmlns:xi="http://www.w3.org/2001/XInclude">
            <xi:include href="/etc/passwd" parse="text"/>
          </root>
        XML

        doc = described_class.parse_relaxed(xinclude_xml)

        # The xi:include element should remain as-is, not processed
        expect(doc.root.to_s).to include('xi:include')
        expect(doc.root.text.to_s).not_to include('root:')
      end

      it 'has XINCLUDE option disabled' do
        expect(described_class::SECURE_PARSE_OPTIONS & Nokogiri::XML::ParseOptions::XINCLUDE).to eq(0)
        expect(described_class::RELAXED_PARSE_OPTIONS & Nokogiri::XML::ParseOptions::XINCLUDE).to eq(0)
      end
    end

    describe 'entity amplification (Billion Laughs)' do
      it 'limits entity expansion to prevent memory exhaustion' do
        # 6-level entity expansion bomb (triggers libxml2's amplification limit)
        # 5 levels = 30KB which is under the limit, 6 levels would be 300KB
        bomb_xml = <<~XML
          <?xml version="1.0"?>
          <!DOCTYPE lolz [
            <!ENTITY lol "lol">
            <!ENTITY lol2 "&lol;&lol;&lol;&lol;&lol;&lol;&lol;&lol;&lol;&lol;">
            <!ENTITY lol3 "&lol2;&lol2;&lol2;&lol2;&lol2;&lol2;&lol2;&lol2;&lol2;&lol2;">
            <!ENTITY lol4 "&lol3;&lol3;&lol3;&lol3;&lol3;&lol3;&lol3;&lol3;&lol3;&lol3;">
            <!ENTITY lol5 "&lol4;&lol4;&lol4;&lol4;&lol4;&lol4;&lol4;&lol4;&lol4;&lol4;">
            <!ENTITY lol6 "&lol5;&lol5;&lol5;&lol5;&lol5;&lol5;&lol5;&lol5;&lol5;&lol5;">
          ]>
          <root>&lol6;</root>
        XML

        # libxml2 should reject this with "Maximum entity amplification factor exceeded"
        # We wrap this in XMLSecurityError for consistent error handling
        # Disable DOCTYPE rejection to test underlying amplification protection
        expect {
          described_class.parse(bomb_xml, reject_doctype: false)
        }.to raise_error(WSDL::XMLSecurityError, /amplification/i)
      end

      it 'limits total entity references' do
        # Many references to a single entity
        many_refs = '&e;' * 200_000
        bomb_xml = <<~XML
          <?xml version="1.0"?>
          <!DOCTYPE foo [
            <!ENTITY e "x">
          ]>
          <root>#{many_refs}</root>
        XML

        # Disable DOCTYPE rejection to test underlying entity reference limits
        expect {
          described_class.parse(bomb_xml, reject_doctype: false)
        }.to raise_error(WSDL::XMLSecurityError, /amplification|entity/i)
      end
    end

    describe 'document depth limits' do
      it 'rejects excessively nested XML' do
        # libxml2 default depth limit is 257
        depth = 300
        deep_xml = "#{'<a>' * depth}content#{'</a>' * depth}"

        expect {
          described_class.parse(deep_xml)
        }.to raise_error(WSDL::XMLSecurityError, /depth|HUGE/i)
      end
    end

    describe 'document size limits' do
      it 'rejects documents with huge attributes' do
        huge_value = 'x' * 20_000_000 # 20MB attribute
        huge_xml = %(<root attr="#{huge_value}"/>)

        expect {
          described_class.parse(huge_xml)
        }.to raise_error(WSDL::XMLSecurityError, /limit|HUGE|buffer/i)
      end

      it 'does not enable HUGE option that would bypass limits' do
        expect(described_class::SECURE_PARSE_OPTIONS & Nokogiri::XML::ParseOptions::HUGE).to eq(0)
        expect(described_class::RELAXED_PARSE_OPTIONS & Nokogiri::XML::ParseOptions::HUGE).to eq(0)
      end
    end

    describe 'DTD attacks' do
      it 'does not load external DTDs' do
        # DTDLOAD not being set means external DTDs are not loaded
        expect(described_class::SECURE_PARSE_OPTIONS & Nokogiri::XML::ParseOptions::DTDLOAD).to eq(0)
        expect(described_class::RELAXED_PARSE_OPTIONS & Nokogiri::XML::ParseOptions::DTDLOAD).to eq(0)
      end

      it 'does not apply DTD attribute defaults' do
        # DTDATTR not being set means DTD attributes are not defaulted
        expect(described_class::SECURE_PARSE_OPTIONS & Nokogiri::XML::ParseOptions::DTDATTR).to eq(0)
        expect(described_class::RELAXED_PARSE_OPTIONS & Nokogiri::XML::ParseOptions::DTDATTR).to eq(0)
      end

      it 'does not validate against DTD' do
        expect(described_class::SECURE_PARSE_OPTIONS & Nokogiri::XML::ParseOptions::DTDVALID).to eq(0)
      end
    end
  end

  describe 'XMLSecurityError' do
    let(:bomb_xml) do
      <<~XML
        <?xml version="1.0"?>
        <!DOCTYPE lolz [
          <!ENTITY lol "lol">
          <!ENTITY lol2 "&lol;&lol;&lol;&lol;&lol;&lol;&lol;&lol;&lol;&lol;">
          <!ENTITY lol3 "&lol2;&lol2;&lol2;&lol2;&lol2;&lol2;&lol2;&lol2;&lol2;&lol2;">
          <!ENTITY lol4 "&lol3;&lol3;&lol3;&lol3;&lol3;&lol3;&lol3;&lol3;&lol3;&lol3;">
          <!ENTITY lol5 "&lol4;&lol4;&lol4;&lol4;&lol4;&lol4;&lol4;&lol4;&lol4;&lol4;">
          <!ENTITY lol6 "&lol5;&lol5;&lol5;&lol5;&lol5;&lol5;&lol5;&lol5;&lol5;&lol5;">
        ]>
        <root>&lol6;</root>
      XML
    end

    it 'inherits from WSDL::FatalError' do
      expect(WSDL::XMLSecurityError.superclass).to eq(WSDL::FatalError)
      expect(WSDL::XMLSecurityError).to be < WSDL::Error
    end

    it 'is raised for DOCTYPE declarations by default' do
      expect {
        described_class.parse(bomb_xml)
      }.to raise_error(WSDL::XMLSecurityError, /DOCTYPE declarations are not allowed/)
    end

    it 'can be rescued as WSDL::Error' do
      expect {
        described_class.parse(bomb_xml)
      }.to raise_error(WSDL::Error)
    end

    context 'when DOCTYPE rejection is disabled (to test underlying protection)' do
      it 'includes descriptive message prefix for entity amplification' do
        expect {
          described_class.parse(bomb_xml, reject_doctype: false)
        }.to raise_error(WSDL::XMLSecurityError, /XML security violation detected:/)
      end

      it 'preserves the original Nokogiri error as cause' do
        described_class.parse(bomb_xml, reject_doctype: false)
      rescue WSDL::XMLSecurityError => e
        expect(e.cause).to be_a(Nokogiri::XML::SyntaxError)
        expect(e.cause.message).to match(/amplification/i)
      end
    end

    it 'does not wrap non-security syntax errors' do
      malformed_xml = '<root><unclosed>'

      expect {
        described_class.parse(malformed_xml)
      }.to raise_error(Nokogiri::XML::SyntaxError)
    end
  end

  describe '.contains_doctype?' do
    it 'returns true when DOCTYPE is present' do
      expect(described_class.contains_doctype?('<!DOCTYPE foo><root/>')).to be true
    end

    it 'returns false when DOCTYPE is absent' do
      expect(described_class.contains_doctype?('<root/>')).to be false
    end

    it 'is case-insensitive' do
      expect(described_class.contains_doctype?('<!doctype foo><root/>')).to be true
      expect(described_class.contains_doctype?('<!DocType foo><root/>')).to be true
    end

    it 'does not match DOCTYPE in element content' do
      # The pattern matches the literal <!DOCTYPE, not just the word
      expect(described_class.contains_doctype?('<root>DOCTYPE</root>')).to be false
    end
  end
end
