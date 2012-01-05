require "spec_helper"

describe WSDL::Parser do
  context "with: blz_service.wsdl" do

    subject do
      WSDL::Parser.new fixture("blz_service.wsdl").to_doc
    end

    describe "#parse" do
      it "returns the expected result" do
        definition = subject.parse
        definition.should have(2).messages
      end
    end

  end
end
