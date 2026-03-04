# frozen_string_literal: true

require 'spec_helper'
require_relative '../../wsdl/security/verifier/shared_context'

RSpec.describe WSDL::Response::SecurityContext, :verifier_helpers do
  include_context 'verifier test helpers'

  let(:verification) { WSDL::Security::ResponseVerification::Options.default }
  let(:certificate_option) { nil }
  let(:context) { described_class.new(xml, verification, certificate: certificate_option) }

  # Helper to build a minimal SOAP response without security
  def unsigned_response_xml
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
        <soap:Header/>
        <soap:Body>
          <Response>OK</Response>
        </soap:Body>
      </soap:Envelope>
    XML
  end

  # Helper to build a response signed only over Timestamp and then tamper Body.
  def tampered_response_with_timestamp_only_signature
    signed = build_signed_response_without_body_reference

    doc = Nokogiri::XML(signed)
    doc.at_xpath('//soap:Body//*[local-name()="Name"]', ns).content = 'Mallory'
    doc.to_xml
  end

  # Helper to build a SOAP response with timestamp only (no signature)
  def response_with_timestamp_xml(created:, expires:)
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
                     xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"
                     xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">
        <soap:Header>
          <wsse:Security soap:mustUnderstand="1">
            <wsu:Timestamp wsu:Id="Timestamp-123">
              <wsu:Created>#{created}</wsu:Created>
              <wsu:Expires>#{expires}</wsu:Expires>
            </wsu:Timestamp>
          </wsse:Security>
        </soap:Header>
        <soap:Body>
          <Response>OK</Response>
        </soap:Body>
      </soap:Envelope>
    XML
  end

  # Helper to build an unsigned response with expired timestamp
  def unsigned_response_with_expired_timestamp
    past_time = Time.now.utc - 7200 # 2 hours ago
    response_with_timestamp_xml(
      created: (past_time - 300).xmlschema,
      expires: past_time.xmlschema
    )
  end

  # Helper to build an unsigned response with recently expired timestamp (10 min ago)
  def unsigned_response_with_recently_expired_timestamp
    past_time = Time.now.utc - 600 # 10 minutes ago
    response_with_timestamp_xml(
      created: (past_time - 300).xmlschema,
      expires: past_time.xmlschema
    )
  end

  # Helper to build verification options with custom timestamp settings
  def verification_with_timestamp(validate:, tolerance_seconds: 300)
    WSDL::Security::ResponseVerification::Options.new(
      certificate: WSDL::Security::ResponseVerification::Certificate.default,
      timestamp: WSDL::Security::ResponseVerification::Timestamp.new(
        validate:,
        tolerance_seconds:
      )
    )
  end

  describe '#initialize' do
    it 'requires raw XML string input' do
      doc = Nokogiri::XML(unsigned_response_xml)
      expect { described_class.new(doc) }.to raise_error(ArgumentError, /Expected String/)
    end
  end

  describe '#valid?' do
    context 'when response has no signature' do
      let(:xml) { unsigned_response_xml }

      it 'returns false' do
        expect(context.valid?).to be false
      end
    end

    context 'when response has valid signature and fresh timestamp' do
      let(:xml) { signed_soap_response }

      it 'returns true' do
        expect(context.valid?).to be true
      end
    end
  end

  describe '#verify!' do
    context 'when response has no signature' do
      let(:xml) { unsigned_response_xml }

      it 'raises SignatureVerificationError' do
        expect { context.verify! }
          .to raise_error(WSDL::SignatureVerificationError, /does not contain a signature/)
      end
    end

    # NOTE: Testing signature valid + timestamp expired requires building a signed
    # response with a custom timestamp, which is complex. We test timestamp validation
    # separately via verify_timestamp! and test the combined flow with valid timestamps.

    context 'when signature and timestamp are valid' do
      let(:xml) { signed_soap_response }

      it 'returns true' do
        expect(context.verify!).to be true
      end
    end
  end

  describe '#signature_present?' do
    context 'when response has no signature' do
      let(:xml) { unsigned_response_xml }

      it 'returns false' do
        expect(context.signature_present?).to be false
      end
    end

    context 'when response has a signature' do
      let(:xml) { signed_soap_response }

      it 'returns true' do
        expect(context.signature_present?).to be true
      end
    end
  end

  describe '#signature_valid?' do
    context 'when response has no signature' do
      let(:xml) { unsigned_response_xml }

      it 'returns false' do
        expect(context.signature_valid?).to be false
      end
    end

    context 'when response has valid signature' do
      let(:xml) { signed_soap_response }

      it 'returns true' do
        expect(context.signature_valid?).to be true
      end
    end

    context 'when signed response is pretty-printed' do
      let(:xml) { Nokogiri::XML(signed_soap_response).to_xml(indent: 2) }

      it 'still returns true' do
        expect(context.signature_valid?).to be true
      end
    end
  end

  describe '#verify_signature!' do
    context 'when response has no signature' do
      let(:xml) { unsigned_response_xml }

      it 'raises SignatureVerificationError' do
        expect { context.verify_signature! }
          .to raise_error(WSDL::SignatureVerificationError, /does not contain a signature/)
      end
    end

    context 'when response has valid signature' do
      let(:xml) { signed_soap_response }

      it 'returns true' do
        expect(context.verify_signature!).to be true
      end
    end

    context 'when signature does not cover SOAP Body' do
      let(:xml) { tampered_response_with_timestamp_only_signature }

      it 'raises SignatureVerificationError' do
        expect { context.verify_signature! }
          .to raise_error(WSDL::SignatureVerificationError, /reference to the SOAP Body/)
      end
    end
  end

  describe '#signed_elements' do
    context 'when response has signature' do
      let(:xml) { signed_soap_response }

      it 'returns the names of signed elements' do
        expect(context.signed_elements).to include('Body')
      end
    end

    context 'when response has no signature' do
      let(:xml) { unsigned_response_xml }

      it 'returns empty array' do
        expect(context.signed_elements).to be_empty
      end
    end
  end

  describe '#signed_element_ids' do
    context 'when response has signature' do
      let(:xml) { signed_soap_response }

      it 'returns the IDs of signed elements' do
        expect(context.signed_element_ids).not_to be_empty
        expect(context.signed_element_ids.first).to be_a(String)
      end
    end
  end

  describe '#timestamp_present?' do
    context 'when response has no timestamp' do
      let(:xml) { unsigned_response_xml }

      it 'returns false' do
        expect(context.timestamp_present?).to be false
      end
    end

    context 'when response has timestamp' do
      let(:xml) { signed_soap_response }

      it 'returns true' do
        expect(context.timestamp_present?).to be true
      end
    end
  end

  describe '#timestamp_valid?' do
    context 'when timestamp validation is disabled' do
      let(:xml) { signed_soap_response }
      let(:verification) { verification_with_timestamp(validate: false) }

      it 'returns true regardless of timestamp' do
        expect(context.timestamp_valid?).to be true
      end
    end

    context 'when timestamp validation is enabled (default)' do
      let(:xml) { signed_soap_response }

      it 'validates the timestamp' do
        # The timestamp is generated at test time, so it should be valid
        expect(context.timestamp_valid?).to be true
      end
    end

    context 'when no timestamp is present' do
      let(:xml) { unsigned_response_xml }

      it 'returns true (timestamps are optional)' do
        expect(context.timestamp_valid?).to be true
      end
    end
  end

  describe '#verify_timestamp!' do
    context 'when timestamp validation is disabled' do
      let(:xml) { signed_soap_response }
      let(:verification) { verification_with_timestamp(validate: false) }

      it 'returns true without checking' do
        expect(context.verify_timestamp!).to be true
      end
    end

    context 'when no timestamp is present' do
      let(:xml) { unsigned_response_xml }

      it 'returns true' do
        expect(context.verify_timestamp!).to be true
      end
    end

    context 'when timestamp has expired' do
      # Use unsigned response - timestamp validation doesn't require signature
      let(:xml) { unsigned_response_with_expired_timestamp }

      it 'raises TimestampValidationError' do
        expect { context.verify_timestamp! }
          .to raise_error(WSDL::TimestampValidationError, /Timestamp validation failed/)
      end

      it 'uses a single timestamp validator instance for failure details' do
        allow(WSDL::Security::Verifier::TimestampValidator).to receive(:new).and_call_original

        expect { context.verify_timestamp! }
          .to raise_error(WSDL::TimestampValidationError, /Timestamp has expired/)
        expect(WSDL::Security::Verifier::TimestampValidator).to have_received(:new).once
      end
    end

    context 'when timestamp is valid' do
      let(:xml) { signed_soap_response }

      it 'returns true' do
        expect(context.verify_timestamp!).to be true
      end
    end
  end

  describe '#timestamp' do
    context 'when response has timestamp' do
      let(:xml) { signed_soap_response }

      it 'returns hash with created_at and expires_at' do
        result = context.timestamp
        expect(result).to be_a(Hash)
        expect(result).to have_key(:created_at)
        expect(result).to have_key(:expires_at)
      end

      it 'returns Time objects' do
        result = context.timestamp
        expect(result[:created_at]).to be_a(Time)
        expect(result[:expires_at]).to be_a(Time)
      end
    end

    context 'when response has no timestamp' do
      let(:xml) { unsigned_response_xml }

      it 'returns nil' do
        expect(context.timestamp).to be_nil
      end
    end
  end

  describe '#errors' do
    context 'when verification passes' do
      let(:xml) { signed_soap_response }

      before do
        context.valid?
      end

      it 'returns empty array' do
        expect(context.errors).to be_empty
      end
    end

    context 'when signature-only verification fails' do
      let(:xml) { build_signed_response_without_body_reference }

      before do
        context.signature_valid?
      end

      it 'includes signature validation errors' do
        expect(context.errors).to include('SignedInfo must contain a reference to the SOAP Body')
      end
    end
  end

  describe '#signature_algorithm' do
    context 'when response has signature' do
      let(:xml) { signed_soap_response }

      it 'returns the signature algorithm URI' do
        expect(context.signature_algorithm).to be_a(String)
        expect(context.signature_algorithm).to include('xmldsig')
      end
    end
  end

  describe '#digest_algorithm' do
    context 'when response has signature' do
      let(:xml) { signed_soap_response }

      it 'returns the digest algorithm URI' do
        expect(context.digest_algorithm).to be_a(String)
      end
    end
  end

  describe '#signing_certificate' do
    context 'when response has signature with embedded certificate' do
      let(:xml) { signed_soap_response }

      it 'returns the certificate' do
        expect(context.signing_certificate).to be_a(OpenSSL::X509::Certificate)
      end
    end

    context 'when response has no signature' do
      let(:xml) { unsigned_response_xml }

      it 'returns nil' do
        expect(context.signing_certificate).to be_nil
      end
    end
  end

  describe 'options handling' do
    let(:xml) { signed_soap_response }

    describe 'certificate keyword argument' do
      let(:certificate_option) { certificate }

      it 'passes certificate to verifier' do
        expect(context.signing_certificate).to eq(certificate)
      end
    end

    describe 'timestamp.validate option' do
      context 'when set to false' do
        # Use unsigned response with expired timestamp
        let(:xml) { unsigned_response_with_expired_timestamp }
        let(:verification) { verification_with_timestamp(validate: false) }

        it 'skips timestamp validation' do
          # Even with expired timestamp, should pass because validation is disabled
          expect(context.timestamp_valid?).to be true
        end
      end

      context 'when set to true (default)' do
        # Use unsigned response with expired timestamp
        let(:xml) { unsigned_response_with_expired_timestamp }
        let(:verification) { verification_with_timestamp(validate: true) }

        it 'performs timestamp validation' do
          expect(context.timestamp_valid?).to be false
        end
      end
    end

    describe 'timestamp.tolerance_seconds option' do
      # Use unsigned response with timestamp that expired 10 minutes ago
      let(:xml) { unsigned_response_with_recently_expired_timestamp }

      context 'with large tolerance (1 hour)' do
        let(:verification) { verification_with_timestamp(validate: true, tolerance_seconds: 3600) }

        it 'accepts timestamps within tolerance' do
          # 10 minutes expired is within 1 hour tolerance
          expect(context.timestamp_valid?).to be true
        end
      end

      context 'with small tolerance (1 minute)' do
        let(:verification) { verification_with_timestamp(validate: true, tolerance_seconds: 60) }

        it 'rejects timestamps outside tolerance' do
          # 10 minutes expired is outside 1 minute tolerance
          expect(context.timestamp_valid?).to be false
        end
      end
    end
  end
end
