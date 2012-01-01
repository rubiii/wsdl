require "spec_helper"

describe WSDL::QName do

  subject do
    WSDL::QName.new("wsdl:service")
  end

  describe "#qname" do
    it "returns the qname" do
      subject.qname.should == "wsdl:service"
    end
  end

  describe "#prefix" do
    it "returns the prefix" do
      subject.prefix.should == "wsdl"
    end
  end

  describe "#local" do
    it "returns the local" do
      subject.local.should == "service"
    end
  end

end
