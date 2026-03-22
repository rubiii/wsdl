# frozen_string_literal: true

# Integration tests for XML Signature Wrapping (XSW) attack detection.
#
# Each test starts from a legitimately signed SOAP envelope (produced by
# SecurityHeader) and then tampers with the signed XML using Nokogiri to
# create a specific XSW attack variant. The full Verifier pipeline must
# reject every payload.
#
# References:
# - https://www.ws-attacks.org/XML_Signature_Wrapping
# - https://www.w3.org/TR/xmldsig-bestpractices/
# - McIntosh & Austel, "XML Signature Element Wrapping Attacks and Countermeasures" (SWS 2005)
RSpec.describe 'XSW attack vectors', :verifier_helpers do
  let(:signed_xml) { build_signed_response(body_id: 'Body-xsw') }
  let(:doc) { Nokogiri::XML(signed_xml) }

  def verify(xml)
    WSDL::Security::Verifier.new(xml, validate_timestamp: false)
  end

  # ------------------------------------------------------------------
  # XSW #1: Body displacement
  #
  # Move the legitimately signed Body into a wrapper element inside
  # the Envelope. Place an unsigned malicious Body in the correct
  # position. The verifier finds the signed Body by ID and validates
  # its digest, but the application would process the unsigned Body.
  # ------------------------------------------------------------------
  describe 'XSW #1: Body displacement' do
    it 'rejects a signed Body wrapped inside Envelope with unsigned Body in correct position' do
      body = doc.at_xpath('//soap:Body', ns)
      envelope = doc.at_xpath('//soap:Envelope', ns)

      # Wrap signed Body inside a wrapper element within Envelope
      wrapper = Nokogiri::XML::Node.new('OriginalWrapper', doc)
      envelope.add_child(wrapper)
      wrapper.add_child(body)

      # Insert unsigned malicious Body in correct position (direct child of Envelope)
      malicious_body = Nokogiri::XML::Node.new('Body', doc)
      malicious_body.default_namespace = ns['soap']
      malicious_body.inner_html = '<MaliciousContent><admin>true</admin></MaliciousContent>'
      envelope.add_child(malicious_body)

      verifier = verify(doc.to_xml)
      expect(verifier.valid?).to be false
      expect(verifier.errors.join('; ')).to match(/Body.*direct child.*Envelope|wrapping attack/i)
    end
  end

  # ------------------------------------------------------------------
  # XSW #2: Body cloning with duplicate ID
  #
  # Clone the signed Body into the Security header with the same wsu:Id.
  # An attacker hopes the verifier validates the cloned copy while the
  # application processes the original.
  # ------------------------------------------------------------------
  describe 'XSW #2: Body cloning with duplicate ID' do
    it 'rejects a document with duplicate Body IDs' do
      body = doc.at_xpath('//soap:Body', ns)
      security = doc.at_xpath('//wsse:Security', ns)

      # Clone Body into Security header (same ID)
      cloned_body = body.dup
      security.add_child(cloned_body)

      verifier = verify(doc.to_xml)
      expect(verifier.valid?).to be false
      expect(verifier.errors.join('; ')).to match(/duplicate.*id/i)
    end
  end

  # ------------------------------------------------------------------
  # XSW #3: Signature relocation
  #
  # Move the ds:Signature element out of wsse:Security to soap:Header.
  # ------------------------------------------------------------------
  describe 'XSW #3: Signature relocation' do
    it 'rejects a Signature moved outside the Security header' do
      signature = doc.at_xpath('//ds:Signature', ns)
      header = doc.at_xpath('//soap:Header', ns)

      # Move Signature to be a direct child of soap:Header
      header.add_child(signature)

      verifier = verify(doc.to_xml)
      expect(verifier.valid?).to be false
      expect(verifier.errors.join('; ')).to match(/Signature.*must be within.*Security/i)
    end
  end

  # ------------------------------------------------------------------
  # XSW #4: Timestamp displacement
  #
  # Move the signed Timestamp out of the Security header and replace
  # it with an unsigned Timestamp with extended expiry. The verifier
  # should reject because the signed Timestamp is in the wrong position.
  # ------------------------------------------------------------------
  describe 'XSW #4: Timestamp displacement' do
    it 'rejects when the signed Timestamp is moved outside the Security header' do
      timestamp = doc.at_xpath('//wsu:Timestamp', ns)
      header = doc.at_xpath('//soap:Header', ns)

      # Moving the Timestamp to soap:Header detaches it from the wsu:
      # namespace context declared on Security's children. The wsu:Id
      # attribute becomes unresolvable, so find_element_by_id fails.
      header.add_child(timestamp)

      verifier = verify(doc.to_xml)
      expect(verifier.valid?).to be false
      expect(verifier.errors.join('; ')).to match(/referenced element not found/i)
    end
  end

  # ------------------------------------------------------------------
  # XSW #5: Signature relocation to Body
  #
  # Move the ds:Signature into the SOAP Body. This is another variant
  # of signature relocation — the Signature must live in the Security
  # header per WS-Security spec.
  # ------------------------------------------------------------------
  describe 'XSW #5: Signature relocation to Body' do
    it 'rejects a Signature moved into the SOAP Body' do
      signature = doc.at_xpath('//ds:Signature', ns)
      body = doc.at_xpath('//soap:Body', ns)

      body.add_child(signature)

      verifier = verify(doc.to_xml)
      expect(verifier.valid?).to be false
      expect(verifier.errors.join('; ')).to match(/Signature.*must be within.*Security/i)
    end
  end

  # ------------------------------------------------------------------
  # XSW #6: Envelope wrapping
  #
  # Wrap the entire original Envelope inside a new outer Envelope.
  # Insert a malicious Body in the outer Envelope. The verifier should
  # fail because the signed Body is no longer a direct child of the
  # outermost Envelope.
  # ------------------------------------------------------------------
  describe 'XSW #6: Envelope wrapping' do
    it 'rejects a signed envelope wrapped inside a new outer envelope' do
      # Build a new outer envelope that wraps the original signed envelope.
      # Strip the inner XML declaration to produce valid XML.
      inner = signed_xml.sub(/<\?xml[^?]*\?>\s*/, '')
      outer_xml = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <soap:Envelope xmlns:soap="#{ns['soap']}">
          <soap:Header/>
          <soap:Body>
            <MaliciousContent><admin>true</admin></MaliciousContent>
            #{inner}
          </soap:Body>
        </soap:Envelope>
      XML

      verifier = verify(outer_xml)
      expect(verifier.valid?).to be false
    end
  end

  # ------------------------------------------------------------------
  # XSW #7: Detached Body with ID stripping
  #
  # Remove the wsu:Id from the original Body, add a new unsigned Body
  # with the signed ID. Keep original Body content but without the ID
  # so the verifier resolves the ID to the attacker's element.
  # ------------------------------------------------------------------
  describe 'XSW #7: ID theft via attribute stripping' do
    it 'rejects when signed Body ID is moved to a different element' do
      body = doc.at_xpath('//soap:Body', ns)
      body_id = body.attribute_with_ns('Id', ns['wsu']).value

      # Strip ID from legitimate Body
      body.remove_attribute('wsu:Id')

      # Add fake element with stolen ID inside Security header
      security = doc.at_xpath('//wsse:Security', ns)
      fake = Nokogiri::XML::Node.new('Body', doc)
      fake.default_namespace = ns['soap']
      fake['wsu:Id'] = body_id
      fake.add_namespace('wsu', ns['wsu'])
      fake.inner_html = '<FakeContent><admin>true</admin></FakeContent>'
      security.add_child(fake)

      verifier = verify(doc.to_xml)
      expect(verifier.valid?).to be false
      expect(verifier.errors.join('; ')).to match(/Body.*direct child.*Envelope|wrapping attack/i)
    end
  end

  # ------------------------------------------------------------------
  # XSW #8: Additional unsigned Signature
  #
  # Add a second ds:Signature element in the Security header that
  # references different elements. The verifier should only process
  # one Signature — the first one found — and its references.
  # ------------------------------------------------------------------
  describe 'XSW #8: Additional Signature injection (appended)' do
    it 'ignores a second Signature appended after the legitimate one' do
      security = doc.at_xpath('//wsse:Security', ns)

      fake_sig = <<~XML
        <ds:Signature xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
          <ds:SignedInfo>
            <ds:CanonicalizationMethod Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"/>
            <ds:SignatureMethod Algorithm="http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"/>
            <ds:Reference URI="#FakeBody-999">
              <ds:Transforms>
                <ds:Transform Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"/>
              </ds:Transforms>
              <ds:DigestMethod Algorithm="http://www.w3.org/2001/04/xmlenc#sha256"/>
              <ds:DigestValue>ZmFrZWRpZ2VzdA==</ds:DigestValue>
            </ds:Reference>
          </ds:SignedInfo>
          <ds:SignatureValue>ZmFrZXNpZw==</ds:SignatureValue>
        </ds:Signature>
      XML

      fake_node = Nokogiri::XML::DocumentFragment.parse(fake_sig)
      security.add_child(fake_node)

      # Verifier uses at_xpath (first match). The legitimate Signature
      # is first, so it validates. The appended fake is ignored.
      verifier = verify(doc.to_xml)
      expect(verifier.valid?).to be true
      expect(verifier.signed_elements).not_to include('FakeBody')
    end
  end

  # ------------------------------------------------------------------
  # XSW #9: Signature replacement (prepended)
  #
  # Prepend an attacker's Signature before the legitimate one. Since
  # the verifier uses at_xpath (first match), the attacker's Signature
  # becomes the one that gets verified. Its SignatureValue won't match
  # because the attacker doesn't have the private key.
  # ------------------------------------------------------------------
  describe 'XSW #9: Signature replacement (prepended)' do
    it 'rejects when an attacker Signature is prepended before the legitimate one' do
      legitimate_sig = doc.at_xpath('//ds:Signature', ns)

      fake_sig = <<~XML
        <ds:Signature xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
          <ds:SignedInfo>
            <ds:CanonicalizationMethod Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"/>
            <ds:SignatureMethod Algorithm="http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"/>
            <ds:Reference URI="#FakeBody-999">
              <ds:Transforms>
                <ds:Transform Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"/>
              </ds:Transforms>
              <ds:DigestMethod Algorithm="http://www.w3.org/2001/04/xmlenc#sha256"/>
              <ds:DigestValue>ZmFrZWRpZ2VzdA==</ds:DigestValue>
            </ds:Reference>
          </ds:SignedInfo>
          <ds:SignatureValue>ZmFrZXNpZw==</ds:SignatureValue>
        </ds:Signature>
      XML

      fake_node = Nokogiri::XML::DocumentFragment.parse(fake_sig)
      legitimate_sig.add_previous_sibling(fake_node)

      # The attacker's Signature is now first. The verifier picks it up
      # and it fails because the fake references don't resolve or verify.
      verifier = verify(doc.to_xml)
      expect(verifier.valid?).to be false
    end
  end

  # ------------------------------------------------------------------
  # SOAP 1.2 variants
  #
  # Verify structural defenses work with SOAP 1.2 namespace, not just 1.1.
  # ------------------------------------------------------------------
  describe 'SOAP 1.2 variants' do
    let(:soap_twelve_xml) { build_signed_response(body_id: 'Body-xsw-soap-twelve', soap_namespace: WSDL::NS::SOAP_1_2) }
    let(:soap_twelve_doc) { Nokogiri::XML(soap_twelve_xml) }

    it 'rejects body displacement with SOAP 1.2' do
      body = soap_twelve_doc.at_xpath('//soap12:Body', ns)
      envelope = soap_twelve_doc.at_xpath('//soap12:Envelope', ns)

      wrapper = Nokogiri::XML::Node.new('OriginalWrapper', soap_twelve_doc)
      envelope.add_child(wrapper)
      wrapper.add_child(body)

      malicious_body = Nokogiri::XML::Node.new('Body', soap_twelve_doc)
      malicious_body.default_namespace = WSDL::NS::SOAP_1_2
      malicious_body.inner_html = '<MaliciousContent><admin>true</admin></MaliciousContent>'
      envelope.add_child(malicious_body)

      verifier = verify(soap_twelve_doc.to_xml)
      expect(verifier.valid?).to be false
      expect(verifier.errors.join('; ')).to match(/Body.*direct child.*Envelope|wrapping attack/i)
    end

    it 'rejects envelope wrapping with SOAP 1.2' do
      inner = soap_twelve_xml.sub(/<\?xml[^?]*\?>\s*/, '')
      outer_xml = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <soap:Envelope xmlns:soap="#{WSDL::NS::SOAP_1_2}">
          <soap:Header/>
          <soap:Body>
            <MaliciousContent><admin>true</admin></MaliciousContent>
            #{inner}
          </soap:Body>
        </soap:Envelope>
      XML

      verifier = verify(outer_xml)
      expect(verifier.valid?).to be false
    end
  end

  # ------------------------------------------------------------------
  # Timestamp cloning with duplicate ID
  #
  # Same pattern as XSW #2 but targeting the Timestamp element.
  # Clone the signed Timestamp with the same wsu:Id.
  # ------------------------------------------------------------------
  describe 'Timestamp cloning with duplicate ID' do
    it 'rejects a document with duplicate Timestamp IDs' do
      timestamp = doc.at_xpath('//wsu:Timestamp', ns)
      envelope = doc.at_xpath('//soap:Envelope', ns)

      # Clone Timestamp to a different location (as sibling of Envelope's Header)
      cloned_timestamp = timestamp.dup
      envelope.add_child(cloned_timestamp)

      verifier = verify(doc.to_xml)
      expect(verifier.valid?).to be false
      expect(verifier.errors.join('; ')).to match(/duplicate.*id/i)
    end
  end

  # ------------------------------------------------------------------
  # Certificate swap
  #
  # Replace the BinarySecurityToken with a different certificate.
  # The cryptographic signature should fail because the public key
  # no longer matches the private key that produced the SignatureValue.
  # ------------------------------------------------------------------
  describe 'certificate swap' do
    it 'rejects when BinarySecurityToken is replaced with a different certificate' do
      bst = doc.at_xpath('//wsse:BinarySecurityToken', ns)
      bst.content = Base64.strict_encode64(other_certificate.to_der)

      verifier = verify(doc.to_xml)
      expect(verifier.valid?).to be false
    end
  end

  # ------------------------------------------------------------------
  # General tampering (not XSW, but ensures crypto defenses hold)
  # ------------------------------------------------------------------
  describe 'general tampering' do
    it 'rejects a Body with tampered content (digest mismatch)' do
      body = doc.at_xpath('//soap:Body', ns)
      body.children.each(&:remove)
      body.inner_html = '<TransferMoney><amount>1000000</amount></TransferMoney>'

      verifier = verify(doc.to_xml)
      expect(verifier.valid?).to be false
      expect(verifier.errors.join('; ')).to match(/digest mismatch/i)
    end

    it 'rejects a modified SignedInfo (signature mismatch)' do
      digest_method = doc.at_xpath('//ds:SignedInfo/ds:Reference/ds:DigestMethod', ns)
      digest_method['Algorithm'] = 'http://www.w3.org/2001/04/xmlenc#sha512'

      verifier = verify(doc.to_xml)
      expect(verifier.valid?).to be false
    end
  end

  # ------------------------------------------------------------------
  # Static fixture tests
  #
  # Verify that the existing hand-crafted XSW fixtures are also
  # rejected by the full Verifier pipeline (not just individual
  # validators).
  # ------------------------------------------------------------------
  describe 'static XSW fixtures' do
    let(:fixture_path) { File.join(__dir__, '..', 'fixtures', 'security') }

    # Fixtures use expired test certs — skip validity checks to test structural defenses.
    def verify_fixture(xml)
      WSDL::Security::Verifier.new(xml, validate_timestamp: false, check_validity: false)
    end

    it 'rejects xsw_duplicate_id.xml' do
      xml = File.read(File.join(fixture_path, 'xsw_duplicate_id.xml'))
      verifier = verify_fixture(xml)
      expect(verifier.valid?).to be false
      expect(verifier.errors.join('; ')).to match(/duplicate.*id/i)
    end

    it 'rejects xsw_body_in_wrong_position.xml' do
      xml = File.read(File.join(fixture_path, 'xsw_body_in_wrong_position.xml'))
      verifier = verify_fixture(xml)
      expect(verifier.valid?).to be false
      expect(verifier.errors.join('; ')).to match(/Body.*direct child.*Envelope|wrapping attack/i)
    end

    it 'rejects xsw_signature_outside_security.xml' do
      xml = File.read(File.join(fixture_path, 'xsw_signature_outside_security.xml'))
      verifier = verify_fixture(xml)
      expect(verifier.valid?).to be false
      expect(verifier.errors.join('; ')).to match(/Signature.*must be within.*Security/i)
    end
  end
end
