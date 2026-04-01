# frozen_string_literal: true

module WSDL
  class Definition
    # Extracts named complex types and anonymous complex types on globally-
    # referenced elements into a shared registry, replacing inline
    # children/attributes with compact +type_ref+ keys.
    #
    # Runs after {NamespaceCompactor} in the Builder pipeline. Elements with
    # a +complex_type_id+ (format +"namespace_uri:localName"+) are extracted
    # into a +types+ registry keyed by +"nsIndex:localName"+. Elements with
    # an +element_ref_id+ (same format) but no +complex_type_id+ are extracted
    # under an +"e:nsIndex:localName"+ key, keeping the two key spaces disjoint.
    #
    # Processing is depth-first: children are compacted before their parent,
    # so registry entries for parent types already contain compacted children
    # (with +type_ref+ instead of inline children).
    #
    # @example Named type extraction
    #   types, compacted = TypeCompactor.call(services, namespaces)
    #   types['0:UserType'] #=> { 'children' => [...] }
    #
    # @example Element-ref extraction
    #   types['e:0:Items'] #=> { 'children' => [...] }
    #
    # @api private
    #
    class TypeCompactor
      # Key prefix for element-ref type registry entries, keeping them disjoint
      # from named complex type keys which use bare +"nsIndex:localName"+ format.
      #
      # @return [String]
      ELEMENT_REF_KEY_PREFIX = 'e:'

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

      # Counts children that carry a +complex_type_id+, +element_ref_id+,
      # or their own +children+ array.
      #
      # @param entry [Hash] a type registry entry
      # @return [Integer]
      def structured_count(entry)
        children = entry['children'] || []
        children.count do |c|
          c.key?('complex_type_id') || c.key?('element_ref_id') || c.key?('children') || c.key?('type_ref')
        end
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

        extracted = extract_type(result)
        return extracted if extracted

        result.delete('element_ref_id') if result.key?('element_ref_id')
        result.freeze
      end

      # Attempts to extract a named complex type or element-ref type into the
      # registry. Returns the compacted element on success, or +nil+ if neither
      # extraction path applies.
      #
      # @param result [Hash] mutable element hash with compacted children
      # @return [Hash, nil] frozen element with +type_ref+, or nil
      def extract_type(result)
        complex_type_id = result['complex_type_id']
        return register_type(result, build_type_key(complex_type_id)) if complex_type_id

        element_ref_id = result['element_ref_id']
        return unless element_ref_id && result['type'] == 'complex'

        register_element_ref_type(result,
          build_element_ref_key(element_ref_id))
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

      # Registers an element-ref type in the registry. Like {#register_type}
      # but deletes +element_ref_id+ instead of +complex_type_id+.
      #
      # @param result [Hash] mutable element hash with compacted children
      # @param key [String] compact registry key (+"e:nsIndex:localName"+)
      # @return [Hash] frozen element with type_ref replacing inline content
      def register_element_ref_type(result, key)
        entry = build_type_entry(result)
        @types[key] = entry.freeze if !@types.key?(key) || richer_entry?(entry, @types[key])

        result['type_ref'] = key
        result.delete('children')
        result.delete('attributes')
        result.delete('element_ref_id')
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
      # computed via {#build_type_key}. When it carries an +element_ref_id+, the
      # key is computed via {#build_element_ref_key}. Otherwise, falls back to
      # {#record_recursive_label_brute_force} which maps all possible namespace
      # indices.
      #
      # @param element [Hash] element with +type+ = +'recursive'+
      # @return [void]
      def record_recursive_label(element)
        recursive_type = element['recursive_type']

        if element['complex_type_id']
          key = build_type_key(element['complex_type_id'])
          @recursive_labels[key] ||= recursive_type
        elsif element['element_ref_id']
          key = build_element_ref_key(element['element_ref_id'])
          @recursive_labels[key] ||= recursive_type
        else
          record_recursive_label_brute_force(recursive_type)
        end
      end

      # Brute-force fallback for recording recursive labels when neither
      # +complex_type_id+ nor +element_ref_id+ is available. Maps all
      # namespace indices as candidates because the QName prefix cannot be
      # resolved to a URI at this stage.
      #
      # @param recursive_type [String] the recursive type QName
      # @return [void]
      def record_recursive_label_brute_force(recursive_type)
        colon_pos = recursive_type.index(':')
        return unless colon_pos

        local_name = recursive_type[(colon_pos + 1)..]

        @ns_map.each_value do |ns_index|
          candidate_key = "#{ns_index}:#{local_name}"
          @recursive_labels[candidate_key] ||= recursive_type
        end
      end

      # Builds a compact registry key from a full complex_type_id string.
      #
      # @param complex_type_id [String] format +"namespace_uri:localName"+
      # @return [String] compact key +"nsIndex:localName"+
      def build_type_key(complex_type_id)
        colon_pos = complex_type_id.rindex(':')
        return complex_type_id unless colon_pos

        ns_uri = complex_type_id[0...colon_pos]
        local_name = complex_type_id[(colon_pos + 1)..]
        ns_index = @ns_map.fetch(ns_uri)
        "#{ns_index}:#{local_name}"
      end

      # Builds an element-ref registry key from a full element_ref_id string.
      # Uses the {ELEMENT_REF_KEY_PREFIX} to keep element-ref keys disjoint
      # from named complex type keys.
      #
      # @param element_ref_id [String] format +"namespace_uri:localName"+
      # @return [String] compact key +"e:nsIndex:localName"+
      def build_element_ref_key(element_ref_id)
        "#{ELEMENT_REF_KEY_PREFIX}#{build_type_key(element_ref_id)}"
      end
    end
  end
end
