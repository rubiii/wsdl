# frozen_string_literal: true

module WSDL
  class Definition
    # Extracts named complex types from element trees into a shared registry
    # and replaces inline children/attributes with compact +type_ref+ keys.
    #
    # Runs after {NamespaceCompactor} in the Builder pipeline. Elements with
    # a +complex_type_id+ (format +"namespace_uri:localName"+) are extracted
    # into a +types+ registry keyed by +"nsIndex:localName"+. The element's
    # +children+, +attributes+, and +complex_type_id+ fields are replaced by
    # a single +type_ref+ string pointing into the registry.
    #
    # Processing is depth-first: children are compacted before their parent,
    # so registry entries for parent types already contain compacted children
    # (with +type_ref+ instead of inline children).
    #
    # @example
    #   types, compacted = TypeCompactor.call(services, namespaces)
    #   types['0:UserType'] #=> { 'children' => [...] }
    #
    # @api private
    #
    class TypeCompactor
      # Compacts named complex types from a services hash into a type registry.
      #
      # @param services [Hash] the services hash (post-namespace compaction)
      # @param namespaces [Array<String>] the namespace table from {NamespaceCompactor}
      # @return [Array(Hash, Hash)] types registry and compacted services
      def self.call(services, namespaces)
        new(services, namespaces).call
      end

      # @param services [Hash] the services hash (post-namespace compaction)
      # @param namespaces [Array<String>] the namespace table from {NamespaceCompactor}
      def initialize(services, namespaces)
        @services = services
        @ns_map = namespaces.each_with_index.to_h
      end

      # Walks all element trees depth-first, extracting named complex types
      # into a shared registry and replacing inline content with +type_ref+ keys.
      # Also collects +recursive_type+ labels for cycle detection during expansion.
      #
      # @return [Array(Hash, Hash)] types registry and compacted services
      def call
        @types = {}
        @recursive_labels = {}
        compacted = compact_services
        types = @types.dup
        types['_recursive_labels'] = @recursive_labels.freeze unless @recursive_labels.empty?
        [types.freeze, compacted]
      end

      private

      # Returns whether the candidate entry is richer than the existing one.
      #
      # When the same +complex_type_id+ is encountered multiple times, the
      # parser may truncate recursive children in deeper copies. This
      # comparison ensures the fully-expanded version is stored.
      #
      # @param candidate [Hash] proposed registry entry
      # @param existing [Hash] currently registered entry
      # @return [Boolean] true if candidate has more structured children
      def richer_entry?(candidate, existing)
        structured_count(candidate) > structured_count(existing)
      end

      # Counts children that carry a +complex_type_id+ or their own +children+ array.
      #
      # @param entry [Hash] a type registry entry
      # @return [Integer]
      def structured_count(entry)
        children = entry['children'] || []
        children.count { |c| c.key?('complex_type_id') || c.key?('children') || c.key?('type_ref') }
      end

      # Walks all services and compacts their element trees.
      #
      # @return [Hash] new services hash with type_ref replacements
      def compact_services
        @services.transform_values { |svc_data|
          {
            'ports' => svc_data['ports'].transform_values { |port|
              compact_port(port)
            }.freeze
          }.freeze
        }.freeze
      end

      # Compacts all operations within a port.
      #
      # @param port [Hash] a port hash
      # @return [Hash] compacted port
      def compact_port(port)
        result = port.dup
        result['operations'] = port['operations'].transform_values { |entry|
          if entry.is_a?(Array)
            entry.map { |operation| compact_operation(operation) }.freeze
          else
            compact_operation(entry)
          end
        }.freeze
        result.freeze
      end

      # Compacts input and output messages of an operation.
      #
      # @param operation [Hash] an operation hash
      # @return [Hash] compacted operation
      def compact_operation(operation)
        result = operation.dup
        result['input'] = compact_message(operation['input']) if operation['input']
        result['output'] = compact_message(operation['output']) if operation['output']
        result.freeze
      end

      # Compacts header and body elements of a message.
      #
      # @param message [Hash] a message hash with 'header' and 'body' arrays
      # @return [Hash] compacted message
      def compact_message(message)
        {
          'header' => message['header'].map { |el| compact_element(el) }.freeze,
          'body' => message['body'].map { |el| compact_element(el) }.freeze
        }.freeze
      end

      # Compacts a single element depth-first. Children are processed before
      # the parent so that registry entries contain already-compacted children.
      # Also records +recursive_type+ labels from parser-truncated elements.
      #
      # @param element [Hash] an element hash
      # @return [Hash] compacted element (with type_ref if named complex type)
      def compact_element(element)
        result = element.dup
        record_recursive_label(element) if element['type'] == 'recursive' && element['recursive_type']
        result['children'] = result['children'].map { |c| compact_element(c) }.freeze if result['children']

        complex_type_id = result['complex_type_id']
        return result.freeze unless complex_type_id

        register_type(result, build_type_key(complex_type_id))
      end

      # Registers a type entry in the registry and replaces inline content
      # with a +type_ref+ pointer.
      #
      # @param result [Hash] mutable element hash with compacted children
      # @param key [String] compact registry key (+"nsIndex:localName"+)
      # @return [Hash] frozen element with type_ref replacing inline content
      def register_type(result, key)
        entry = build_type_entry(result)
        @types[key] = entry.freeze if !@types.key?(key) || richer_entry?(entry, @types[key])

        result['type_ref'] = key
        result.delete('children')
        result.delete('attributes')
        result.delete('complex_type_id')
        result.freeze
      end

      # Builds a type registry entry from an element's children and attributes.
      #
      # @param element [Hash] element hash with optional +children+ and +attributes+
      # @return [Hash] registry entry
      def build_type_entry(element)
        entry = {}
        entry['children'] = element['children'] if element['children']
        entry['attributes'] = element['attributes'] if element['attributes']
        entry
      end

      # Records a +recursive_type+ label for later use during expansion.
      #
      # When the element carries a +complex_type_id+, the exact registry key is
      # computed via {#build_type_key}. Otherwise, all possible namespace-index
      # keys are mapped as a best-effort fallback (the recursive_type QName
      # prefix cannot be resolved to a URI at this stage).
      #
      # @param element [Hash] element with +type+ = +'recursive'+
      # @return [void]
      def record_recursive_label(element)
        recursive_type = element['recursive_type']

        if element['complex_type_id']
          key = build_type_key(element['complex_type_id'])
          @recursive_labels[key] ||= recursive_type
        else
          colon_pos = recursive_type.index(':')
          return unless colon_pos

          local_name = recursive_type[(colon_pos + 1)..]

          @ns_map.each_value do |ns_index|
            candidate_key = "#{ns_index}:#{local_name}"
            @recursive_labels[candidate_key] ||= recursive_type
          end
        end
      end

      # Builds a compact registry key from a full complex_type_id string.
      #
      # @param complex_type_id [String] format +"namespace_uri:localName"+
      # @return [String] compact key +"nsIndex:localName"+
      def build_type_key(complex_type_id)
        colon_pos = complex_type_id.rindex(':')
        ns_uri = complex_type_id[0...colon_pos]
        local_name = complex_type_id[(colon_pos + 1)..]
        ns_index = @ns_map.fetch(ns_uri)
        "#{ns_index}:#{local_name}"
      end
    end
  end
end
