# frozen_string_literal: true

module WSDL
  module Parser
    # Represents a single parsed WSDL document.
    #
    # Parses a WSDL XML document and provides access to its various sections
    # including messages, bindings, port types, and services. Also extracts
    # XML Schema definitions embedded within the WSDL.
    #
    # @api private
    #
    class Document
      # Creates a new Document by parsing a Nokogiri XML document.
      #
      # @param document [Nokogiri::XML::Document] the parsed WSDL XML document
      # @param schemas [Schema::Collection] the schema collection for resolving types
      def initialize(document, schemas)
        @document = document
        @schemas = schemas

        @messages = {}
        @bindings = {}
        @port_types = {}
        @services = {}

        collect_sections(
          'message' => { collection: @messages, container: MessageInfo, qualified: true },
          'binding' => { collection: @bindings, container: Binding, qualified: true },
          'portType' => { collection: @port_types, container: PortType, qualified: true },
          'service' => { collection: @services, container: Service }
        )
      end

      # @return [Hash{QualifiedName => MessageInfo}] the messages defined in this document
      attr_reader :messages

      # @return [Hash{QualifiedName => PortType}] the port types defined in this document
      attr_reader :port_types

      # @return [Hash{QualifiedName => Binding}] the bindings defined in this document
      attr_reader :bindings

      # @return [Hash{String => Service}] the services defined in this document
      attr_reader :services

      # Returns the name of the WSDL definitions element.
      #
      # @return [String] the service name from the root element's name attribute
      def service_name
        @document.root['name']
      end

      # Returns the target namespace of this WSDL document.
      #
      # @return [String] the target namespace URI
      def target_namespace
        @target_namespace ||= QualifiedName.document_namespace(@document.root)
      end

      # Returns the XML Schemas defined within this WSDL document.
      #
      # Schemas are typically found within the wsdl:types element.
      #
      # @param source_location [String, nil] the location this document was loaded from,
      #   used for resolving relative imports/includes within the schemas
      # @return [Array<Schema::Definition>] the parsed schema objects
      def schemas(source_location = nil)
        schema_nodes.map { |node| Schema::Definition.new(node, @schemas, source_location) }
      end

      # Returns the locations of imported WSDL documents.
      #
      # @return [Array<String>] the import locations
      def imports
        imports = []

        @document.root.xpath('wsdl:import', 'wsdl' => NS::WSDL).each do |node|
          location = node['location']
          imports << location if location
        end

        imports
      end

      private

      # Collects sections from the WSDL document and stores them in their respective collections.
      #
      # @param mapping [Hash] a mapping of section names to collection and container info
      # @return [void]
      def collect_sections(mapping)
        section_types = mapping.keys

        @document.root.element_children.each do |node|
          section_type = node.name
          next unless section_types.include? section_type

          node_name = node['name']
          type_mapping = mapping.fetch(section_type)

          collection = type_mapping[:collection]
          container = type_mapping[:container]
          qualified = type_mapping[:qualified]
          key = qualified ? QualifiedName.new(target_namespace, node_name) : node_name

          collection[key] = container.new(node)
        end
      end

      # Returns the schema nodes from this document.
      #
      # @return [Array<Nokogiri::XML::Node>] the schema element nodes
      def schema_nodes
        @schema_nodes ||= schema_nodes! || []
      end

      # Finds and returns schema nodes from the document.
      #
      # If the root element is a schema, returns it directly.
      # Otherwise, looks for schemas within the wsdl:types element.
      #
      # @return [Array<Nokogiri::XML::Node>, nil] the schema nodes or nil if none found
      def schema_nodes!
        root = @document.root
        return [root] if root.name == 'schema'

        types = root.at_xpath('wsdl:types', 'wsdl' => NS::WSDL)
        types&.element_children
      end
    end
  end
end
