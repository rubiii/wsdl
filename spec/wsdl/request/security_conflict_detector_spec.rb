# frozen_string_literal: true

RSpec.describe WSDL::Request::SecurityConflictDetector do
  subject(:detector) { described_class.new(document:, security:) }

  let(:document) { WSDL::Request::Envelope.new }
  let(:security) { WSDL::Security::Config.new }

  describe '#validate!' do
    context 'when security is not configured' do
      it 'does nothing' do
        document.header << WSDL::Request::Node.new(
          name: 'wsse:Security',
          prefix: 'wsse',
          local_name: 'Security',
          namespace_uri: WSDL::Security::Constants::NS::Security::WSSE
        )

        expect { detector.validate! }.not_to raise_error
      end
    end

    context 'when security is configured with timestamp' do
      before do
        security.timestamp
      end

      it 'raises for manual wsse:Security element in header' do
        document.header << WSDL::Request::Node.new(
          name: 'wsse:Security',
          prefix: 'wsse',
          local_name: 'Security',
          namespace_uri: WSDL::Security::Constants::NS::Security::WSSE
        )

        expect { detector.validate! }.to raise_error(
          WSDL::RequestSecurityConflictError, /conflicts with generated WS-Security/
        )
      end

      it 'raises for manual wsu:Timestamp element in header' do
        document.header << WSDL::Request::Node.new(
          name: 'wsu:Timestamp',
          prefix: 'wsu',
          local_name: 'Timestamp',
          namespace_uri: WSDL::Security::Constants::NS::Security::WSU
        )

        expect { detector.validate! }.to raise_error(
          WSDL::RequestSecurityConflictError, /conflicts with generated WS-Security/
        )
      end

      it 'raises for manual ds:Signature element in header' do
        document.header << WSDL::Request::Node.new(
          name: 'ds:Signature',
          prefix: 'ds',
          local_name: 'Signature',
          namespace_uri: WSDL::Security::Constants::NS::Signature::DS
        )

        expect { detector.validate! }.to raise_error(
          WSDL::RequestSecurityConflictError, /conflicts with generated WS-Security/
        )
      end

      it 'allows non-conflicting header elements' do
        document.header << WSDL::Request::Node.new(
          name: 'AuthToken', prefix: nil, local_name: 'AuthToken'
        )

        expect { detector.validate! }.not_to raise_error
      end

      it 'allows header elements with no namespace' do
        document.header << WSDL::Request::Node.new(
          name: 'Custom', prefix: nil, local_name: 'Custom', namespace_uri: nil
        )

        expect { detector.validate! }.not_to raise_error
      end

      it 'detects conflicts in nested header elements' do
        parent = WSDL::Request::Node.new(name: 'Wrapper', prefix: nil, local_name: 'Wrapper')
        child = WSDL::Request::Node.new(
          name: 'wsse:UsernameToken',
          prefix: 'wsse',
          local_name: 'UsernameToken',
          namespace_uri: WSDL::Security::Constants::NS::Security::WSSE
        )
        parent.children << child
        document.header << parent

        expect { detector.validate! }.to raise_error(WSDL::RequestSecurityConflictError)
      end
    end

    context 'when security is configured with signature' do
      let(:private_key) { OpenSSL::PKey::RSA.new(2048) }
      let(:certificate) do
        cert = OpenSSL::X509::Certificate.new
        cert.version = 2
        cert.serial = 1
        cert.subject = OpenSSL::X509::Name.new([%w[CN Test]])
        cert.issuer = cert.subject
        cert.public_key = private_key.public_key
        cert.not_before = Time.now
        cert.not_after = Time.now + 3600
        cert.sign(private_key, OpenSSL::Digest.new('SHA256'))
        cert
      end

      before do
        security.signature(certificate:, private_key:)
      end

      it 'raises for manual wsu:Id attribute on body elements' do
        body_node = WSDL::Request::Node.new(name: 'Data', prefix: nil, local_name: 'Data')
        body_node.attributes << WSDL::Request::Attribute.new(
          'wsu:Id', 'wsu', 'Id', 'Body-123', WSDL::Security::Constants::NS::Security::WSU
        )
        document.body << body_node

        expect { detector.validate! }.to raise_error(
          WSDL::RequestSecurityConflictError, /conflicts with generated signature references/
        )
      end

      it 'detects wsu:Id conflicts in nested body elements' do
        parent = WSDL::Request::Node.new(name: 'Outer', prefix: nil, local_name: 'Outer')
        child = WSDL::Request::Node.new(name: 'Inner', prefix: nil, local_name: 'Inner')
        child.attributes << WSDL::Request::Attribute.new(
          'wsu:Id', 'wsu', 'Id', 'Body-456', WSDL::Security::Constants::NS::Security::WSU
        )
        parent.children << child
        document.body << parent

        expect { detector.validate! }.to raise_error(WSDL::RequestSecurityConflictError)
      end

      it 'allows body elements without wsu:Id' do
        body_node = WSDL::Request::Node.new(name: 'Data', prefix: nil, local_name: 'Data')
        body_node.attributes << WSDL::Request::Attribute.new('id', nil, 'id', 'my-id', nil)
        document.body << body_node

        expect { detector.validate! }.not_to raise_error
      end
    end
  end
end
