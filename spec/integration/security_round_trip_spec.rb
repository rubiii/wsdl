# frozen_string_literal: true

require 'spec_helper'
require_relative '../wsdl/security/verifier/shared_context'

# Integration tests for sign + verify round-trip.
#
# These tests sign a SOAP envelope with SecurityHeader and then verify the
# resulting XML with Verifier, ensuring both halves of the WS-Security
# implementation are compatible across cross-cutting option combinations.
#
# Individual dimension tests (single algorithm, single key reference, tampering,
# etc.) live in spec/wsdl/security/verifier_spec.rb. This file focuses on
# combination coverage and the higher-level SecurityContext/Response APIs.
RSpec.describe 'Security sign + verify round-trip', :verifier_helpers do
  def sign_envelope(envelope_xml, cert: certificate, key: private_key, **options)
    config = WSDL::Security::Config.new
    config.timestamp
    config.signature(
      certificate: cert,
      private_key: key,
      digest_algorithm: options.fetch(:digest_algorithm, :sha256),
      key_reference: options.fetch(:key_reference, :binary_security_token),
      sign_timestamp: options.fetch(:sign_timestamp, true),
      explicit_namespace_prefixes: options.fetch(:explicit_namespace_prefixes, false)
    )

    WSDL::Security::SecurityHeader.new(config).apply(envelope_xml)
  end

  def build_envelope(soap_namespace:, body_id:)
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <soap:Envelope xmlns:soap="#{soap_namespace}">
        <soap:Header/>
        <soap:Body xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="#{body_id}">
          <GetUserResponse xmlns="http://example.com/users">
            <User><Name>John Doe</Name><Email>john@example.com</Email></User>
          </GetUserResponse>
        </soap:Body>
      </soap:Envelope>
    XML
  end

  let(:soap_1_1_envelope) { build_envelope(soap_namespace: WSDL::NS::SOAP_1_1, body_id: 'Body-roundtrip') }

  # ============================================================
  # Response::SecurityContext Round-Trip
  # ============================================================

  describe 'Response::SecurityContext round-trip' do
    let(:signed_xml) { sign_envelope(soap_1_1_envelope) }

    let(:verification_options) do
      WSDL::Security::ResponseVerification::Options.new(
        certificate: WSDL::Security::ResponseVerification::Certificate.new(
          trust_store: nil,
          verify_not_expired: true
        ),
        timestamp: WSDL::Security::ResponseVerification::Timestamp.new(
          validate: true,
          tolerance_seconds: 300
        )
      )
    end

    it 'validates via SecurityContext#valid?' do
      ctx = WSDL::Response::SecurityContext.new(signed_xml, verification_options)
      expect(ctx.valid?).to be true
    end

    it 'validates via SecurityContext#verify!' do
      ctx = WSDL::Response::SecurityContext.new(signed_xml, verification_options)
      expect { ctx.verify! }.not_to raise_error
    end

    it 'reports signed elements' do
      ctx = WSDL::Response::SecurityContext.new(signed_xml, verification_options)
      expect(ctx.signed_elements).to contain_exactly('Body', 'Timestamp')
    end

    it 'exposes the signing certificate' do
      ctx = WSDL::Response::SecurityContext.new(signed_xml, verification_options)
      expect(ctx.signing_certificate).to be_a(OpenSSL::X509::Certificate)
      expect(ctx.signing_certificate.subject.to_s).to include('Test Certificate')
    end

    it 'raises SignatureVerificationError for tampered body' do
      doc = Nokogiri::XML(signed_xml)
      doc.at_xpath('//soap:Body', ns).children.first.content = 'TAMPERED'
      ctx = WSDL::Response::SecurityContext.new(doc.to_xml, verification_options)
      expect { ctx.verify! }.to raise_error(WSDL::SignatureVerificationError)
    end

    it 'raises SignatureVerificationError for unsigned response' do
      ctx = WSDL::Response::SecurityContext.new(unsigned_soap_response, verification_options)
      expect { ctx.verify! }.to raise_error(WSDL::SignatureVerificationError, /does not contain a signature/)
    end
  end

  # ============================================================
  # Response Object Round-Trip
  # ============================================================

  describe 'Response object round-trip' do
    let(:signed_xml) { sign_envelope(soap_1_1_envelope) }

    it 'validates signature through Response#security' do
      response = WSDL::Response.new(http: WSDL::HTTPResponse.new(status: 200, body: signed_xml))
      expect(response.security.valid?).to be true
      expect(response.security.signed_elements).to contain_exactly('Body', 'Timestamp')
    end

    it 'provides signature algorithm info' do
      response = WSDL::Response.new(http: WSDL::HTTPResponse.new(status: 200, body: signed_xml))
      expect(response.security.signature_algorithm).to include('rsa-sha256')
    end
  end

  # ============================================================
  # Combination Matrix
  # ============================================================

  describe 'combination matrix' do
    combos = [
      { digest: :sha1, ref: :binary_security_token, soap: WSDL::NS::SOAP_1_1, ts: true, ns_prefix: false },
      { digest: :sha256, ref: :issuer_serial, soap: WSDL::NS::SOAP_1_1, ts: true, ns_prefix: false },
      { digest: :sha512, ref: :binary_security_token, soap: WSDL::NS::SOAP_1_2, ts: false, ns_prefix: true },
      { digest: :sha256, ref: :binary_security_token, soap: WSDL::NS::SOAP_1_1, ts: false, ns_prefix: true },
      { digest: :sha256, ref: :subject_key_identifier, soap: WSDL::NS::SOAP_1_2, ts: true, ns_prefix: false }
    ]

    combos.each_with_index do |combo, idx|
      soap_label = combo[:soap].include?('1.2') ? '1.2' : '1.1'
      context "#{combo[:digest].upcase}/#{combo[:ref]}/SOAP#{soap_label}/" \
              "ts=#{combo[:ts]}/explicit_ns=#{combo[:ns_prefix]}" do
        let(:envelope) { build_envelope(soap_namespace: combo[:soap], body_id: "Body-combo-#{idx}") }

        let(:signed_xml) do
          sign_envelope(
            envelope,
            digest_algorithm: combo[:digest],
            key_reference: combo[:ref],
            sign_timestamp: combo[:ts],
            explicit_namespace_prefixes: combo[:ns_prefix]
          )
        end

        let(:trust_store) do
          combo[:ref] == :binary_security_token ? nil : [certificate]
        end

        it 'round-trips successfully' do
          verifier = WSDL::Security::Verifier.new(signed_xml, trust_store:)
          expect(verifier.valid?).to be(true), -> { "Errors: #{verifier.errors.join('; ')}" }
        end

        it 'signs the expected elements' do
          verifier = WSDL::Security::Verifier.new(signed_xml, trust_store:)
          verifier.valid?

          expected = combo[:ts] ? %w[Body Timestamp] : %w[Body]
          expect(verifier.signed_elements).to match_array(expected)
        end
      end
    end
  end
end
