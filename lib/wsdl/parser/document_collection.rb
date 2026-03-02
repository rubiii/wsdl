# frozen_string_literal: true

module WSDL
  module Parser
    # A collection of parsed WSDL documents.
    #
    # This class aggregates multiple WSDL documents that may be imported
    # from a single root WSDL. It provides unified access to messages,
    # port types, bindings, and services across all imported documents.
    #
    # @api private
    #
    class DocumentCollection
      include Enumerable

      # Creates a new empty DocumentCollection.
      def initialize
        @documents = []
      end

      # Adds a document to the collection.
      #
      # @param document [Document] the document to add
      # @return [Array<Document>] the updated documents array
      def <<(document)
        @documents << document
      end

      # Iterates over each document in the collection.
      #
      # @yield [document] yields each document
      # @yieldparam document [Document] a document in the collection
      # @return [Enumerator, Array] an enumerator if no block given, otherwise the documents array
      def each(&)
        @documents.each(&)
      end

      # Returns the service name from the first (root) document.
      #
      # @return [String] the service name
      def service_name
        @service_name ||= first.service_name
      end

      # Returns all messages from all documents in the collection.
      #
      # @return [Hash{QualifiedName => MessageInfo}] a merged hash of all messages keyed by qualified name
      def messages
        @messages ||= collect_sections(:message, &:messages)
      end

      # Returns all port types from all documents in the collection.
      #
      # @return [Hash{QualifiedName => PortType}] a merged hash of all port types keyed by qualified name
      def port_types
        @port_types ||= collect_sections(:port_type, &:port_types)
      end

      # Returns all bindings from all documents in the collection.
      #
      # @return [Hash{QualifiedName => Binding}] a merged hash of all bindings keyed by qualified name
      def bindings
        @bindings ||= collect_sections(:binding, &:bindings)
      end

      # Returns all services from all documents in the collection.
      #
      # @return [Hash{String => Service}] a merged hash of all services keyed by name
      def services
        @services ||= collect_sections(:service, &:services)
      end

      # Returns a port by service and port name.
      #
      # @param service_name [String] the name of the service
      # @param port_name [String] the name of the port
      # @return [Port] the port object
      # @raise [KeyError] if the service or port is not found
      def service_port(service_name, port_name)
        service = services.fetch(service_name)
        service.ports.fetch(port_name)
      end

      private

      # Collects and merges sections from all documents.
      #
      # @yield [document] yields each document to get its section
      # @yieldparam document [Document] a document in the collection
      # @return [Hash] the merged section data from all documents
      def collect_sections(component_type)
        result = {}
        sources = {}

        each do |document|
          sections = yield document
          sections.each do |key, value|
            raise_duplicate_definition_error(component_type, key, sources[key], document) if sources.key?(key)

            sources[key] = document
            result[key] = value
          end
        end

        result
      end

      # Raises a typed error for duplicate definitions across imported documents.
      #
      # @param component_type [Symbol] component type
      # @param key [Object] duplicate key
      # @param existing_document [Document] first document containing the key
      # @param conflicting_document [Document] second document containing the key
      # @return [void]
      def raise_duplicate_definition_error(component_type, key, existing_document, conflicting_document)
        key_value = key.respond_to?(:to_s) ? key.to_s : key.inspect
        first_source = existing_document.target_namespace.inspect
        second_source = conflicting_document.target_namespace.inspect

        raise DuplicateDefinitionError.new(
          "Duplicate #{component_type} definition #{key_value} found in target namespaces " \
          "#{first_source} and #{second_source}",
          component_type:,
          definition_key: key_value
        )
      end
    end
  end
end
