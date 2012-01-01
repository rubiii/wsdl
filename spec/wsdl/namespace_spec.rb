require "spec_helper"

describe WSDL::Namespace do

  subject do
    WSDL::Namespace.new(doc.root)
  end

  let(:doc) do
    Nokogiri.XML('<w:service xmlns:w="http://schemas.xmlsoap.org/wsdl/" name="BLZService" />')
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
