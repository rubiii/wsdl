# frozen_string_literal: true

require 'wsdl/xs/base_type'
require 'wsdl/xs/primary_type'
require 'wsdl/xs/simple_type'
require 'wsdl/xs/element'
require 'wsdl/xs/complex_type'
require 'wsdl/xs/extension'
require 'wsdl/xs/any'
require 'wsdl/xs/compositors'
require 'wsdl/xs/attribute'
require 'wsdl/xs/attribute_group'
require 'wsdl/xs/simple_content'
require 'wsdl/xs/annotation'

class WSDL
  # XML Schema (XSD) type classes for representing schema components.
  #
  # This module contains classes that represent various XML Schema elements
  # and type definitions. They are used to parse and traverse XSD documents
  # embedded within WSDL files or imported externally.
  #
  # @api private
  #
  class XS
    # Mapping of XSD element names to their corresponding Ruby classes.
    #
    # @return [Hash<String, Class>] element name to class mappings
    TYPE_MAPPING = {
      'any' => Any,
      'attribute' => Attribute,
      'attributeGroup' => AttributeGroup,
      'element' => Element,
      'complexType' => ComplexType,
      'simpleType' => SimpleType,
      'simpleContent' => SimpleContent,
      'complexContent' => ComplexContent,
      'extension' => Extension,
      'restriction' => Restriction,
      'all' => All,
      'sequence' => Sequence,
      'choice' => Choice,
      'enumeration' => Enumeration,
      'annotation' => Annotation
    }.freeze

    # Builds an appropriate type object from an XSD node.
    #
    # Uses the {TYPE_MAPPING} to determine the correct class based on
    # the node's element name. Falls back to {AnyType} for unrecognized
    # elements.
    #
    # @param node [Nokogiri::XML::Node] the XSD element node
    # @param schemas [SchemaCollection] the schema collection for resolving references
    # @param schema [Hash] schema context information
    # @return [BaseType] an instance of the appropriate type class
    def self.build(node, schemas, schema = {})
      type_class(node).new(node, schemas, schema)
    end

    # Determines the appropriate class for an XSD node.
    #
    # @param node [Nokogiri::XML::Node] the XSD element node
    # @return [Class] the class to use for this node
    def self.type_class(node)
      type = node.name.split(':').last

      if TYPE_MAPPING.include? type
        TYPE_MAPPING[type]
      else
        logger.debug("No type mapping for #{type.inspect}. ")
        AnyType
      end
    end

    # Returns the logger instance for the XS module.
    #
    # @return [Logging::Logger] the logger instance
    def self.logger
      @logger ||= Logging.logger[self]
    end
  end
end
