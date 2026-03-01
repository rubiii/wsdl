# frozen_string_literal: true

require 'spec_helper'

describe WSDL::Security::Constants do
  describe 'namespace constants' do
    it 'defines NS_WSSE for WS-Security Extension namespace' do
      expect(described_class::NS_WSSE).to eq(
        'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd'
      )
    end

    it 'defines NS_WSU for WS-Security Utility namespace' do
      expect(described_class::NS_WSU).to eq(
        'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd'
      )
    end

    it 'defines NS_DS for XML Digital Signature namespace' do
      expect(described_class::NS_DS).to eq('http://www.w3.org/2000/09/xmldsig#')
    end

    it 'defines NS_EC for Exclusive Canonicalization namespace' do
      expect(described_class::NS_EC).to eq('http://www.w3.org/2001/10/xml-exc-c14n#')
    end
  end

  describe 'UsernameToken Profile URIs' do
    it 'defines PASSWORD_TEXT_URI for plain text passwords' do
      expect(described_class::PASSWORD_TEXT_URI).to include('#PasswordText')
    end

    it 'defines PASSWORD_DIGEST_URI for digest passwords' do
      expect(described_class::PASSWORD_DIGEST_URI).to include('#PasswordDigest')
    end
  end

  describe 'X.509 Token Profile URIs' do
    it 'defines X509_V3_URI for X.509 v3 certificates' do
      expect(described_class::X509_V3_URI).to include('#X509v3')
    end

    it 'defines BASE64_ENCODING_URI for Base64 encoding' do
      expect(described_class::BASE64_ENCODING_URI).to include('#Base64Binary')
    end
  end

  describe 'digest algorithm URIs' do
    it 'defines SHA1_URI' do
      expect(described_class::SHA1_URI).to eq('http://www.w3.org/2000/09/xmldsig#sha1')
    end

    it 'defines SHA256_URI' do
      expect(described_class::SHA256_URI).to eq('http://www.w3.org/2001/04/xmlenc#sha256')
    end

    it 'defines SHA512_URI' do
      expect(described_class::SHA512_URI).to eq('http://www.w3.org/2001/04/xmlenc#sha512')
    end
  end

  describe 'signature algorithm URIs' do
    it 'defines RSA_SHA1_URI' do
      expect(described_class::RSA_SHA1_URI).to eq('http://www.w3.org/2000/09/xmldsig#rsa-sha1')
    end

    it 'defines RSA_SHA256_URI' do
      expect(described_class::RSA_SHA256_URI).to eq('http://www.w3.org/2001/04/xmldsig-more#rsa-sha256')
    end

    it 'defines RSA_SHA512_URI' do
      expect(described_class::RSA_SHA512_URI).to eq('http://www.w3.org/2001/04/xmldsig-more#rsa-sha512')
    end
  end

  describe 'canonicalization algorithm URIs' do
    it 'defines EXC_C14N_URI for exclusive canonicalization' do
      expect(described_class::EXC_C14N_URI).to eq('http://www.w3.org/2001/10/xml-exc-c14n#')
    end

    it 'defines C14N_URI for inclusive canonicalization 1.0' do
      expect(described_class::C14N_URI).to eq('http://www.w3.org/TR/2001/REC-xml-c14n-20010315')
    end

    it 'defines C14N_11_URI for inclusive canonicalization 1.1' do
      expect(described_class::C14N_11_URI).to eq('http://www.w3.org/2006/12/xml-c14n11')
    end
  end

  describe 'NAMESPACES hash' do
    it 'maps wsse prefix to WSSE namespace' do
      expect(described_class::NAMESPACES['wsse']).to eq(described_class::NS_WSSE)
    end

    it 'maps wsu prefix to WSU namespace' do
      expect(described_class::NAMESPACES['wsu']).to eq(described_class::NS_WSU)
    end

    it 'maps ds prefix to DS namespace' do
      expect(described_class::NAMESPACES['ds']).to eq(described_class::NS_DS)
    end

    it 'maps ec prefix to EC namespace' do
      expect(described_class::NAMESPACES['ec']).to eq(described_class::NS_EC)
    end

    it 'is frozen' do
      expect(described_class::NAMESPACES).to be_frozen
    end
  end
end
