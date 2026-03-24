# frozen_string_literal: true

# Helper for creating mock schema elements in specs.
#
# Include this module in specs that need to create mock WSDL::XML::Element
# instances for testing response parsing.
#
# @example
#   RSpec.describe MyClass do
#     include SchemaElementHelper
#
#     it 'parses elements' do
#       element = schema_element('Name', type: 'xsd:string')
#       # ...
#     end
#   end
#
module SchemaElementHelper
  # Creates a mock schema element for testing.
  #
  # @param name [String] the element name
  # @param type [String, nil] the XSD type (e.g., 'xsd:string', 'xsd:int')
  # @param singular [Boolean] whether maxOccurs is 1 (true) or > 1 (false)
  # @param children [Array] child elements for complex types
  # @param attributes [Array<Object>] attribute definitions
  # @param nillable [Boolean] whether the element is nillable
  # @param namespace [String, nil] namespace URI of the element
  # @param form [String] element form ('qualified' or 'unqualified')
  # @param list [Boolean] whether this is an xs:list-derived type
  # @return [RSpec::Mocks::Double] a mock WSDL::XML::Element
  # rubocop:disable Metrics/ParameterLists
  def schema_element(name, type: nil, singular: true, children: [], attributes: [],
                     nillable: false, namespace: nil, form: 'qualified', list: false)
    element = instance_double(
      WSDL::XML::Element,
      name:,
      singular?: singular,
      nillable?: nillable,
      children:,
      attributes:,
      namespace:,
      form:
    )

    allow(element).to receive(:list?).and_return(list)

    if type
      allow(element).to receive_messages(simple_type?: true, complex_type?: false, base_type: type)
    elsif children.any? || attributes.any?
      allow(element).to receive_messages(simple_type?: false, complex_type?: true, base_type: nil)
    else
      allow(element).to receive_messages(simple_type?: false, complex_type?: false, base_type: nil)
    end

    element
  end
  # rubocop:enable Metrics/ParameterLists

  # Creates a mock schema attribute for testing.
  #
  # @param name [String] the attribute name
  # @param type [String] the XSD type (e.g., 'xsd:string', 'xsd:int')
  # @param use [String] 'required' or 'optional'
  # @param list [Boolean] whether this is an xs:list-derived type
  # @return [RSpec::Mocks::Double] a mock WSDL::XML::Attribute
  def schema_attribute(name, type: 'xsd:string', use: 'required', list: false)
    instance_double(
      WSDL::XML::Attribute,
      name:,
      base_type: type,
      use:,
      optional?: use == 'optional',
      list?: list
    )
  end
end

RSpec.configure do |config|
  config.include SchemaElementHelper
end
