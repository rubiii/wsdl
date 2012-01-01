require "spec_helper"

describe WSDL::XPath do

  subject { WSDL::XPath.new fixture("blz_service.wsdl").to_doc }

  it "is enumerable" do
    WSDL::XPath.ancestors.should include(Enumerable)
    subject.should respond_to(:each)
  end

  describe "#query" do
    it "returns a child node filtered by a given block" do
      node = subject.query(:name, "definitions")

      node.should be_a(Nokogiri::XML::Element)
      node.name.should == "definitions"
    end
  end

  describe "#wsdl" do
    it "builds a query of 'wsdl' elements" do
      subject.wsdl(:definitions, :service).first.should be_a(Nokogiri::XML::Element)
    end
  end

end
