# frozen_string_literal: true

RSpec.describe WSDL::Security::XmlBuilderHelper do
  let(:ns_ds) { WSDL::Security::Constants::NS::Signature::DS }
  let(:ns_wsse) { WSDL::Security::Constants::NS::Security::WSSE }
  let(:ns_wsu) { WSDL::Security::Constants::NS::Security::WSU }
  let(:ns_ec) { WSDL::Security::Constants::NS::Signature::EC }

  describe '#initialize' do
    it 'defaults explicit_prefixes to false' do
      helper = described_class.new
      expect(helper.explicit_prefixes).to be false
    end

    it 'accepts explicit_prefixes option' do
      helper = described_class.new(explicit_prefixes: true)
      expect(helper.explicit_prefixes).to be true
    end
  end

  describe '#build_element' do
    context 'with explicit_prefixes: false' do
      subject(:helper) { described_class.new(explicit_prefixes: false) }

      it 'creates element with default namespace' do
        builder = Nokogiri::XML::Builder.new do |xml|
          helper.build_element(xml, :ds, 'Signature')
        end

        doc = builder.doc
        signature = doc.root

        expect(signature.name).to eq('Signature')
        expect(signature.namespace.href).to eq(ns_ds)
        expect(signature.namespace.prefix).to be_nil
      end

      it 'merges additional attributes' do
        builder = Nokogiri::XML::Builder.new do |xml|
          helper.build_element(xml, :ds, 'Signature', Id: 'sig-123')
        end

        doc = builder.doc
        expect(doc.root['Id']).to eq('sig-123')
      end

      it 'yields to block for child elements' do
        builder = Nokogiri::XML::Builder.new do |xml|
          helper.build_element(xml, :ds, 'Signature') do
            helper.build_child(xml, :ds, 'SignedInfo')
          end
        end

        doc = builder.doc
        # Use local-name() to find element regardless of namespace prefix
        signed_info = doc.at_xpath('//*[local-name()="SignedInfo"]')
        expect(signed_info).not_to be_nil
      end
    end

    context 'with explicit_prefixes: true' do
      subject(:helper) { described_class.new(explicit_prefixes: true) }

      it 'creates element with explicit namespace prefix' do
        builder = Nokogiri::XML::Builder.new do |xml|
          helper.build_element(xml, :ds, 'Signature')
        end

        doc = builder.doc
        signature = doc.root

        expect(signature.name).to eq('Signature')
        expect(signature.namespace.prefix).to eq('ds')
        expect(signature.namespace.href).to eq(ns_ds)
      end

      it 'includes xmlns:prefix declaration' do
        builder = Nokogiri::XML::Builder.new do |xml|
          helper.build_element(xml, :ds, 'Signature')
        end

        xml_output = builder.to_xml
        expect(xml_output).to include('xmlns:ds=')
        expect(xml_output).to include('<ds:Signature')
      end
    end

    context 'with different namespace prefixes' do
      subject(:helper) { described_class.new(explicit_prefixes: true) }

      it 'handles :wsse namespace' do
        builder = Nokogiri::XML::Builder.new do |xml|
          helper.build_element(xml, :wsse, 'Security')
        end

        doc = builder.doc
        expect(doc.root.namespace.href).to eq(ns_wsse)
        expect(doc.root.namespace.prefix).to eq('wsse')
      end

      it 'handles :wsu namespace' do
        builder = Nokogiri::XML::Builder.new do |xml|
          helper.build_element(xml, :wsu, 'Timestamp')
        end

        doc = builder.doc
        expect(doc.root.namespace.href).to eq(ns_wsu)
        expect(doc.root.namespace.prefix).to eq('wsu')
      end

      it 'handles :ec namespace' do
        builder = Nokogiri::XML::Builder.new do |xml|
          helper.build_element(xml, :ec, 'InclusiveNamespaces')
        end

        doc = builder.doc
        expect(doc.root.namespace.href).to eq(ns_ec)
        expect(doc.root.namespace.prefix).to eq('ec')
      end

      it 'raises ArgumentError for unknown namespace' do
        builder = Nokogiri::XML::Builder.new
        expect {
          helper.build_element(builder, :unknown, 'Element')
        }.to raise_error(ArgumentError, /Unknown namespace prefix/)
      end
    end
  end

  describe '#build_child' do
    context 'with explicit_prefixes: false' do
      subject(:helper) { described_class.new(explicit_prefixes: false) }

      it 'creates child element without prefix' do
        builder = Nokogiri::XML::Builder.new do |xml|
          helper.build_element(xml, :ds, 'Root') do
            helper.build_child(xml, :ds, 'SignedInfo')
          end
        end

        doc = builder.doc
        signed_info = doc.at_xpath('//*[local-name()="SignedInfo"]')
        expect(signed_info).not_to be_nil
        expect(signed_info.name).to eq('SignedInfo')
      end

      it 'handles text content' do
        builder = Nokogiri::XML::Builder.new do |xml|
          helper.build_element(xml, :ds, 'Root') do
            helper.build_child(xml, :ds, 'DigestValue', 'abc123')
          end
        end

        doc = builder.doc
        digest_value = doc.at_xpath('//*[local-name()="DigestValue"]')
        expect(digest_value).not_to be_nil
        expect(digest_value.text).to eq('abc123')
      end

      it 'handles attributes hash' do
        builder = Nokogiri::XML::Builder.new do |xml|
          helper.build_element(xml, :ds, 'Root') do
            helper.build_child(xml, :ds, 'Reference', URI: '#body')
          end
        end

        doc = builder.doc
        reference = doc.at_xpath('//*[local-name()="Reference"]')
        expect(reference).not_to be_nil
        expect(reference['URI']).to eq('#body')
      end

      it 'handles attributes hash with block' do
        builder = Nokogiri::XML::Builder.new do |xml|
          helper.build_element(xml, :ds, 'Root') do
            helper.build_child(xml, :ds, 'Reference', URI: '#body') do
              helper.build_child(xml, :ds, 'DigestValue', 'abc123')
            end
          end
        end

        doc = builder.doc
        reference = doc.at_xpath('//*[local-name()="Reference"]')
        expect(reference).not_to be_nil
        expect(reference['URI']).to eq('#body')

        digest_value = reference.at_xpath('*[local-name()="DigestValue"]')
        expect(digest_value).not_to be_nil
        expect(digest_value.text).to eq('abc123')
      end

      it 'handles content with attributes' do
        builder = Nokogiri::XML::Builder.new do |xml|
          helper.build_element(xml, :ds, 'Root') do
            helper.build_child(xml, :ds, 'DigestValue', 'abc123', Id: 'dv-1')
          end
        end

        doc = builder.doc
        digest = doc.at_xpath('//*[local-name()="DigestValue"]')
        expect(digest).not_to be_nil
        expect(digest.text).to eq('abc123')
        expect(digest['Id']).to eq('dv-1')
      end

      it 'yields to block for nested elements' do
        builder = Nokogiri::XML::Builder.new do |xml|
          helper.build_element(xml, :ds, 'Root') do
            helper.build_child(xml, :ds, 'Transforms') do
              helper.build_child(xml, :ds, 'Transform', Algorithm: 'test')
            end
          end
        end

        doc = builder.doc
        transform = doc.at_xpath('//*[local-name()="Transforms"]/*[local-name()="Transform"]')
        expect(transform).not_to be_nil
        expect(transform['Algorithm']).to eq('test')
      end
    end

    context 'with explicit_prefixes: true' do
      subject(:helper) { described_class.new(explicit_prefixes: true) }

      it 'creates child element with prefix' do
        builder = Nokogiri::XML::Builder.new do |xml|
          xml['ds'].Root('xmlns:ds' => ns_ds) do
            helper.build_child(xml, :ds, 'SignedInfo')
          end
        end

        xml_output = builder.to_xml
        expect(xml_output).to include('<ds:SignedInfo')
      end

      it 'handles text content with prefix' do
        builder = Nokogiri::XML::Builder.new do |xml|
          xml['ds'].Root('xmlns:ds' => ns_ds) do
            helper.build_child(xml, :ds, 'DigestValue', 'abc123')
          end
        end

        xml_output = builder.to_xml
        expect(xml_output).to include('<ds:DigestValue>abc123</ds:DigestValue>')
      end

      it 'handles attributes with prefix' do
        builder = Nokogiri::XML::Builder.new do |xml|
          xml['ds'].Root('xmlns:ds' => ns_ds) do
            helper.build_child(xml, :ds, 'Reference', URI: '#body')
          end
        end

        doc = builder.doc
        reference = doc.at_xpath('//ds:Reference', 'ds' => ns_ds)
        expect(reference).not_to be_nil
        expect(reference['URI']).to eq('#body')
      end

      it 'handles attributes with block and prefix' do
        builder = Nokogiri::XML::Builder.new do |xml|
          xml['ds'].Root('xmlns:ds' => ns_ds) do
            helper.build_child(xml, :ds, 'Reference', URI: '#body') do
              helper.build_child(xml, :ds, 'DigestValue', 'abc123')
            end
          end
        end

        xml_output = builder.to_xml
        expect(xml_output).to include('<ds:Reference URI="#body">')
        expect(xml_output).to include('<ds:DigestValue>abc123</ds:DigestValue>')
      end
    end
  end

  describe '#build_child_with_ns' do
    context 'with explicit_prefixes: false' do
      subject(:helper) { described_class.new(explicit_prefixes: false) }

      it 'creates child element with its own namespace declaration' do
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.SecurityTokenReference do
            helper.build_child_with_ns(xml, :ds, 'X509Data')
          end
        end

        doc = builder.doc
        x509_data = doc.at_xpath('//*[local-name()="X509Data"]')
        expect(x509_data).not_to be_nil
        expect(x509_data.namespace.href).to eq(ns_ds)
      end
    end

    context 'with explicit_prefixes: true' do
      subject(:helper) { described_class.new(explicit_prefixes: true) }

      it 'creates child element with explicit prefix and namespace' do
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.SecurityTokenReference do
            helper.build_child_with_ns(xml, :ds, 'X509Data')
          end
        end

        xml_output = builder.to_xml
        expect(xml_output).to include('<ds:X509Data')
        expect(xml_output).to include('xmlns:ds=')
      end

      it 'merges additional attributes' do
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.SecurityTokenReference do
            helper.build_child_with_ns(xml, :ds, 'X509Data', Id: 'x509-1')
          end
        end

        doc = builder.doc
        x509_data = doc.at_xpath('//ds:X509Data', 'ds' => ns_ds)
        expect(x509_data).not_to be_nil
        expect(x509_data['Id']).to eq('x509-1')
      end

      it 'yields to block for nested elements' do
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.SecurityTokenReference do
            helper.build_child_with_ns(xml, :ds, 'X509Data') do
              helper.build_child(xml, :ds, 'X509IssuerSerial')
            end
          end
        end

        xml_output = builder.to_xml
        expect(xml_output).to include('<ds:X509IssuerSerial')
      end
    end
  end

  describe 'integration: building a complete signature structure' do
    context 'with explicit_prefixes: false' do
      subject(:helper) { described_class.new(explicit_prefixes: false) }

      it 'builds a valid SignedInfo structure' do
        builder = Nokogiri::XML::Builder.new do |xml|
          helper.build_element(xml, :ds, 'SignedInfo') do
            helper.build_child(xml, :ds, 'CanonicalizationMethod',
                               Algorithm: 'http://www.w3.org/2001/10/xml-exc-c14n#')
            helper.build_child(xml, :ds, 'SignatureMethod',
                               Algorithm: 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha256')
            helper.build_child(xml, :ds, 'Reference', URI: '#Body-123') do
              helper.build_child(xml, :ds, 'DigestMethod',
                                 Algorithm: 'http://www.w3.org/2001/04/xmlenc#sha256')
              helper.build_child(xml, :ds, 'DigestValue', 'abc123digest')
            end
          end
        end

        doc = builder.doc
        expect(doc.at_xpath('//*[local-name()="SignedInfo"]')).not_to be_nil
        expect(doc.at_xpath('//*[local-name()="CanonicalizationMethod"]/@Algorithm').value).to include('exc-c14n')
        expect(doc.at_xpath('//*[local-name()="Reference"]/@URI').value).to eq('#Body-123')
        expect(doc.at_xpath('//*[local-name()="DigestValue"]').text).to eq('abc123digest')
      end
    end

    context 'with explicit_prefixes: true' do
      subject(:helper) { described_class.new(explicit_prefixes: true) }

      it 'builds a valid SignedInfo structure with ds: prefix' do
        builder = Nokogiri::XML::Builder.new do |xml|
          helper.build_element(xml, :ds, 'SignedInfo') do
            helper.build_child(xml, :ds, 'CanonicalizationMethod',
                               Algorithm: 'http://www.w3.org/2001/10/xml-exc-c14n#')
            helper.build_child(xml, :ds, 'SignatureMethod',
                               Algorithm: 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha256')
            helper.build_child(xml, :ds, 'Reference', URI: '#Body-123') do
              helper.build_child(xml, :ds, 'DigestMethod',
                                 Algorithm: 'http://www.w3.org/2001/04/xmlenc#sha256')
              helper.build_child(xml, :ds, 'DigestValue', 'abc123digest')
            end
          end
        end

        xml_output = builder.to_xml

        expect(xml_output).to include('<ds:SignedInfo')
        expect(xml_output).to include('<ds:CanonicalizationMethod')
        expect(xml_output).to include('<ds:SignatureMethod')
        expect(xml_output).to include('<ds:Reference')
        expect(xml_output).to include('<ds:DigestMethod')
        expect(xml_output).to include('<ds:DigestValue>abc123digest</ds:DigestValue>')
      end
    end
  end
end
