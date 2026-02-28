# frozen_string_literal: true

class WSDL
  class XS
    # Base class for primary XSD type definitions (elements, types).
    #
    # Extends {BaseType} with additional properties common to named
    # schema components: name, namespace, and form (qualified/unqualified).
    #
    class PrimaryType < BaseType
      # Creates a new PrimaryType with namespace and form information.
      #
      # @param node [Nokogiri::XML::Node] the XSD element node
      # @param schemas [SchemaCollection] the schema collection for resolving references
      # @param schema [Hash] schema context with :target_namespace and :element_form_default
      def initialize(node, schemas, schema = {})
        super

        @namespace = schema[:target_namespace]
        @element_form_default = schema[:element_form_default]

        @name = node['name']
        # Because you've overriden the form method, you don't need to set
        # unqualified as the default when no form is specified.
        # @form = node['form'] || 'unqualified'
        @form = node['form']

        @namespaces = node.namespaces
      end

      # @return [String, nil] the local name of this type
      attr_reader :name

      # @return [String, nil] the target namespace URI
      attr_reader :namespace

      # @return [Hash<String, String>] namespace declarations in scope (xmlns:prefix => URI)
      attr_reader :namespaces

      # Returns the element form (qualified or unqualified).
      #
      # If no explicit form is set, uses the schema's elementFormDefault.
      # Falls back to 'unqualified' if neither is specified.
      #
      # @return [String] 'qualified' or 'unqualified'
      def form
        if @form
          @form
        elsif @element_form_default == 'qualified'
          'qualified'
        else
          'unqualified'
        end
      end
    end
  end
end
