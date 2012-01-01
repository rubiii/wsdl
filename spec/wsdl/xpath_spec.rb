require "spec_helper"

describe WSDL::XPath do

  subject do
    WSDL::XPath.new fixture("blz_service.wsdl").to_doc
  end

  it "is enumerable" do
    WSDL::XPath.ancestors.should include(Enumerable)
    subject.should respond_to(:each)
  end

  describe "#wsdl" do
    it "builds a query of 'wsdl' elements" do
      subject.wsdl(:definitions, :service).first.should be_a(Nokogiri::XML::Element)
    end
  end

end
