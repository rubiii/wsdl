# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WSDL::Security::Constants do
  describe 'NS module' do
    describe 'Security' do
      it 'defines WSSE for WS-Security Extension namespace' do
        expect(described_class::NS::Security::WSSE).to eq(
          'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd'
        )
      end

      it 'defines WSU for WS-Security Utility namespace' do
        expect(described_class::NS::Security::WSU).to eq(
          'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd'
        )
      end
    end

    describe 'Signature' do
      it 'defines DS for XML Digital Signature namespace' do
        expect(described_class::NS::Signature::DS).to eq('http://www.w3.org/2000/09/xmldsig#')
      end

      it 'defines EC for Exclusive Canonicalization namespace' do
        expect(described_class::NS::Signature::EC).to eq('http://www.w3.org/2001/10/xml-exc-c14n#')
      end
    end

    describe 'Addressing' do
      it 'defines V1_0 for WS-Addressing 1.0 namespace' do
        expect(described_class::NS::Addressing::V1_0).to eq('http://www.w3.org/2005/08/addressing')
      end

      it 'defines V2004 for legacy WS-Addressing namespace' do
        expect(described_class::NS::Addressing::V2004).to eq('http://schemas.xmlsoap.org/ws/2004/08/addressing')
      end
    end

    describe 'SOAP' do
      it 'defines V1_1 for SOAP 1.1 namespace' do
        expect(described_class::NS::SOAP::V1_1).to eq('http://schemas.xmlsoap.org/soap/envelope/')
      end

      it 'defines V1_2 for SOAP 1.2 namespace' do
        expect(described_class::NS::SOAP::V1_2).to eq('http://www.w3.org/2003/05/soap-envelope')
      end
    end
  end

  describe 'Algorithms module' do
    describe 'Digest' do
      it 'defines SHA1' do
        expect(described_class::Algorithms::Digest::SHA1).to eq('http://www.w3.org/2000/09/xmldsig#sha1')
      end

      it 'defines SHA224' do
        expect(described_class::Algorithms::Digest::SHA224).to eq('http://www.w3.org/2001/04/xmldsig-more#sha224')
      end

      it 'defines SHA256' do
        expect(described_class::Algorithms::Digest::SHA256).to eq('http://www.w3.org/2001/04/xmlenc#sha256')
      end

      it 'defines SHA384' do
        expect(described_class::Algorithms::Digest::SHA384).to eq('http://www.w3.org/2001/04/xmldsig-more#sha384')
      end

      it 'defines SHA512' do
        expect(described_class::Algorithms::Digest::SHA512).to eq('http://www.w3.org/2001/04/xmlenc#sha512')
      end
    end

    describe 'Signature' do
      it 'defines RSA_SHA1' do
        expect(described_class::Algorithms::Signature::RSA_SHA1).to eq('http://www.w3.org/2000/09/xmldsig#rsa-sha1')
      end

      it 'defines RSA_SHA256' do
        expect(described_class::Algorithms::Signature::RSA_SHA256).to eq(
          'http://www.w3.org/2001/04/xmldsig-more#rsa-sha256'
        )
      end

      it 'defines RSA_SHA512' do
        expect(described_class::Algorithms::Signature::RSA_SHA512).to eq(
          'http://www.w3.org/2001/04/xmldsig-more#rsa-sha512'
        )
      end

      it 'defines ECDSA_SHA256' do
        expect(described_class::Algorithms::Signature::ECDSA_SHA256).to eq(
          'http://www.w3.org/2001/04/xmldsig-more#ecdsa-sha256'
        )
      end

      it 'defines DSA_SHA1' do
        expect(described_class::Algorithms::Signature::DSA_SHA1).to eq('http://www.w3.org/2000/09/xmldsig#dsa-sha1')
      end
    end

    describe 'Canonicalization' do
      it 'defines EXCLUSIVE_1_0 for exclusive canonicalization' do
        expect(described_class::Algorithms::Canonicalization::EXCLUSIVE_1_0).to eq(
          'http://www.w3.org/2001/10/xml-exc-c14n#'
        )
      end

      it 'defines EXCLUSIVE_1_0_WITH_COMMENTS' do
        expect(described_class::Algorithms::Canonicalization::EXCLUSIVE_1_0_WITH_COMMENTS).to eq(
          'http://www.w3.org/2001/10/xml-exc-c14n#WithComments'
        )
      end

      it 'defines INCLUSIVE_1_0 for inclusive canonicalization 1.0' do
        expect(described_class::Algorithms::Canonicalization::INCLUSIVE_1_0).to eq(
          'http://www.w3.org/TR/2001/REC-xml-c14n-20010315'
        )
      end

      it 'defines INCLUSIVE_1_1 for inclusive canonicalization 1.1' do
        expect(described_class::Algorithms::Canonicalization::INCLUSIVE_1_1).to eq(
          'http://www.w3.org/2006/12/xml-c14n11'
        )
      end
    end

    describe 'Transform' do
      it 'defines ENVELOPED_SIGNATURE' do
        expect(described_class::Algorithms::Transform::ENVELOPED_SIGNATURE).to eq(
          'http://www.w3.org/2000/09/xmldsig#enveloped-signature'
        )
      end
    end
  end

  describe 'TokenProfiles module' do
    describe 'UsernameToken' do
      it 'defines PASSWORD_TEXT for plain text passwords' do
        expect(described_class::TokenProfiles::UsernameToken::PASSWORD_TEXT).to include('#PasswordText')
      end

      it 'defines PASSWORD_DIGEST for digest passwords' do
        expect(described_class::TokenProfiles::UsernameToken::PASSWORD_DIGEST).to include('#PasswordDigest')
      end
    end

    describe 'X509' do
      it 'defines V3 for X.509 v3 certificates' do
        expect(described_class::TokenProfiles::X509::V3).to include('#X509v3')
      end

      it 'defines SKI for Subject Key Identifier' do
        expect(described_class::TokenProfiles::X509::SKI).to include('#X509SubjectKeyIdentifier')
      end
    end
  end

  describe 'Encoding module' do
    it 'defines BASE64 for Base64 encoding' do
      expect(described_class::Encoding::BASE64).to include('#Base64Binary')
    end
  end

  describe 'KeyReference module' do
    it 'defines BINARY_SECURITY_TOKEN' do
      expect(described_class::KeyReference::BINARY_SECURITY_TOKEN).to eq(:binary_security_token)
    end

    it 'defines ISSUER_SERIAL' do
      expect(described_class::KeyReference::ISSUER_SERIAL).to eq(:issuer_serial)
    end

    it 'defines SUBJECT_KEY_IDENTIFIER' do
      expect(described_class::KeyReference::SUBJECT_KEY_IDENTIFIER).to eq(:subject_key_identifier)
    end
  end

  describe 'NAMESPACE_PREFIXES hash' do
    it 'maps wsse prefix to WSSE namespace' do
      expect(described_class::NAMESPACE_PREFIXES['wsse']).to eq(described_class::NS::Security::WSSE)
    end

    it 'maps wsu prefix to WSU namespace' do
      expect(described_class::NAMESPACE_PREFIXES['wsu']).to eq(described_class::NS::Security::WSU)
    end

    it 'maps ds prefix to DS namespace' do
      expect(described_class::NAMESPACE_PREFIXES['ds']).to eq(described_class::NS::Signature::DS)
    end

    it 'maps ec prefix to EC namespace' do
      expect(described_class::NAMESPACE_PREFIXES['ec']).to eq(described_class::NS::Signature::EC)
    end

    it 'maps wsa prefix to Addressing namespace' do
      expect(described_class::NAMESPACE_PREFIXES['wsa']).to eq(described_class::NS::Addressing::V1_0)
    end

    it 'is frozen' do
      expect(described_class::NAMESPACE_PREFIXES).to be_frozen
    end
  end

  describe 'WS_ADDRESSING_HEADERS' do
    it 'includes standard WS-Addressing header elements' do
      expect(described_class::WS_ADDRESSING_HEADERS).to include('To', 'Action', 'MessageID')
    end

    it 'is frozen' do
      expect(described_class::WS_ADDRESSING_HEADERS).to be_frozen
    end
  end
end
