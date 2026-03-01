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
  # @param nillable [Boolean] whether the element is nillable
  # @return [RSpec::Mocks::Double] a mock WSDL::XML::Element
  def schema_element(name, type: nil, singular: true, children: [], nillable: false)
    element = instance_double(
      WSDL::XML::Element,
      name: name,
      singular?: singular,
      nillable?: nillable,
      children: children
    )

    if type
      allow(element).to receive_messages(simple_type?: true, complex_type?: false, base_type: type)
    elsif children.any?
      allow(element).to receive_messages(simple_type?: false, complex_type?: true, base_type: nil)
    else
      allow(element).to receive_messages(simple_type?: false, complex_type?: false, base_type: nil)
    end

    element
  end
end

RSpec.configure do |config|
  config.include SchemaElementHelper, type: :unit
end
