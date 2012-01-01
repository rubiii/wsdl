require "spec_helper"

describe WSDL::Namespace do

  subject { WSDL::Namespace.new(wsdl_node) }

  let(:wsdl_node) do
    Nokogiri.XML('<w:service xmlns:w="http://schemas.xmlsoap.org/wsdl/" name="BLZService" />').root
  end

  let(:soap11_node) do
    Nokogiri.XML('<s:address xmlns:s="http://schemas.xmlsoap.org/wsdl/soap/" location="http://example.com" />').root
  end

  let(:soap12_node) do
    Nokogiri.XML('<s:address xmlns:s="http://schemas.xmlsoap.org/wsdl/soap12/" location="http://example.com" />').root
  end

  describe "#soap?" do
    context "with a SOAP 1.1 node" do
      subject { WSDL::Namespace.new(soap11_node) }

      it "returns true" do
        subject.should be_soap
      end
    end

    context "with a SOAP 1.2 node" do
      subject { WSDL::Namespace.new(soap12_node) }

      it "returns true" do
        subject.should be_soap
      end
    end

    context "with any other node" do
      it "returns false" do
        subject.should_not be_soap
      end
    end
  end

  describe "#href" do
    it "returns the node's namespace URI" do
      subject.href.should == "http://schemas.xmlsoap.org/wsdl/"
    end
  end

  describe "#type" do
    it "returns the node type" do
      subject.type.should == "wsdl"
    end
  end

end
