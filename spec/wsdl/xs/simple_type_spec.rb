# frozen_string_literal: true

require 'spec_helper'

describe WSDL::XS::SimpleType do
  specify 'complexType/sequence/element' do
    simple_type = new_simple_type('
      <xs:simpleType name="TemperatureUnit" xmlns="http://www.w3.org/2001/XMLSchema">
        <xs:restriction base="xs:string">
          <xs:enumeration value="degreeCelsius" />
          <xs:enumeration value="degreeFahrenheit" />
          <xs:enumeration value="degreeRankine" />
          <xs:enumeration value="degreeReaumur" />
          <xs:enumeration value="kelvin" />
        </xs:restriction>
      </xs:simpleType>
    ')

    expect(simple_type).to be_a(described_class)

    restriction = simple_type.children.first
    expect(restriction).to be_a(WSDL::XS::Restriction)

    enums = restriction.children
    expect(enums.count).to eq(5)

    expect(enums).to all(be_a(WSDL::XS::Enumeration))
  end

  def new_simple_type(xml)
    node = Nokogiri.XML(xml).root
    schemas ||= double('schemas')
    schema = {}

    WSDL::XS::SimpleType.new(node, schemas, schema)
  end
end
