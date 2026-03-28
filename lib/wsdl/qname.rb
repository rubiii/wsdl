# frozen_string_literal: true

module WSDL
  # Represents a fully qualified XML name (QName).
  #
  # A QName consists of a namespace URI and a local name. This value object
  # is used as a stable collection key across imported documents and for
  # resolving type/element/attribute references in schemas.
  #
  # @api private
  QName = Data.define(:namespace, :local) {
    class << self
      # Returns the effective namespace for top-level WSDL components.
      #
      # @param root [Nokogiri::XML::Node] wsdl:definitions root node
      # @return [String, nil] resolved namespace URI
      def document_namespace(root)
        namespace = root['targetNamespace']
        return namespace if namespace && !namespace.empty?

        raise UnresolvedReferenceError.new(
          'WSDL definitions element is missing required targetNamespace',
          reference_type: :namespace,
          reference_name: root.name,
          context: 'wsdl:definitions'
        )
      end

      # Resolves a lexical QName into a namespace/local pair.
      #
      # Returns a lightweight frozen two-element Array instead of allocating
      # a QName instance. Use this on hot paths where only the namespace and
      # local name are needed and the object identity of a QName is not
      # required (e.g. schema lookups that immediately destructure the
      # result).
      #
      # Results are cached by namespaces hash identity so that
      # repeated lookups of the same QName within the same namespace scope
      # return the identical frozen Array without any new allocations.
      #
      # @param qname [String] QName text (for example "tns:MyMessage")
      # @param namespaces [Hash{String => String}] in-scope namespace declarations
      # @param default_namespace [String, nil] fallback namespace for unprefixed names
      # @return [Array(String, String)] frozen [namespace, local] pair
      def resolve(qname, namespaces:, default_namespace: nil)
        cache = resolve_scope_cache(namespaces, default_namespace)
        cache[qname] ||= resolve_uncached(qname, namespaces, default_namespace)
      end

      # Clears all internal resolve caches.
      #
      # Called automatically by {Parser.parse} after every parse run
      # (via +ensure+) so that cached namespace hashes and their
      # referenced Nokogiri nodes can be garbage-collected. In normal
      # usage you do not need to call this yourself.
      #
      # Call it manually only if you use {Parser.import} directly
      # without going through {Parser.parse}.
      #
      # @return [void]
      def clear_resolve_cache
        @resolve_cache = {}.compare_by_identity
        @resolve_dns_cache = {}.compare_by_identity
        @prefix_cache = {}
        nil
      end

      private

      # Returns the inner cache hash for the given namespace scope.
      #
      # When +default_namespace+ is nil (the common case), the cache is a
      # single identity-keyed hash keyed by the +namespaces+ object itself.
      # When present, a second level keyed by the +default_namespace+ string
      # isolates scopes that share the same namespaces hash but differ in
      # their fallback.
      #
      # Using +compare_by_identity+ means only the exact same Hash object
      # shares a cache bucket — structurally equal but distinct hashes get
      # their own scope. This also keeps a strong reference to the
      # namespaces hash, preventing GC from reclaiming it while cached.
      #
      # The top-level cache hashes (+@resolve_cache+, +@resolve_dns_cache+,
      # +@prefix_cache+) are eagerly initialized at class load time by
      # +clear_resolve_cache+ so they are never +nil+. This avoids a race
      # condition where two threads could each create separate cache
      # instances via +||=+, silently discarding one thread's entries.
      #
      # @param namespaces [Hash{String => String}] in-scope namespace declarations
      # @param default_namespace [String, nil] fallback namespace for unprefixed names
      # @return [Hash{String => Array}] qname-to-result cache for this scope
      def resolve_scope_cache(namespaces, default_namespace)
        if default_namespace
          ns_cache = (@resolve_dns_cache[namespaces] ||= {})
          ns_cache[default_namespace] ||= {}
        else
          (@resolve_cache[namespaces] ||= {})
        end
      end

      # Performs the actual QName resolution without caching.
      #
      # Interns the +xmlns:prefix+ lookup key so that repeated prefixes
      # (e.g. "tns", "xs") share a single frozen String allocation.
      #
      # @param qname [String] QName text
      # @param namespaces [Hash{String => String}] in-scope namespace declarations
      # @param default_namespace [String, nil] fallback namespace
      # @return [Array(String, String)] frozen [namespace, local] pair
      def resolve_uncached(qname, namespaces, default_namespace)
        colon = qname.rindex(':')

        if colon
          prefix = qname[0, colon]
          local  = qname[(colon + 1)..]
          key = (@prefix_cache[prefix] ||= -"xmlns:#{prefix}")
          [namespaces[key], local].freeze
        else
          [namespaces['xmlns'] || default_namespace, qname].freeze
        end
      end

      public

      # Parses a lexical QName into a fully qualified name.
      #
      # @param qname [String] QName text (for example "tns:MyMessage")
      # @param namespaces [Hash{String => String}] in-scope namespace declarations
      # @param default_namespace [String, nil] fallback namespace for unprefixed names
      # @return [QName] the resolved qualified name
      def parse(qname, namespaces:, default_namespace: nil)
        raise ArgumentError, 'QName must be a non-empty String' unless qname.is_a?(String) && !qname.empty?

        new(*resolve(qname, namespaces:, default_namespace:))
      end
    end

    # Eagerly initialize class-level caches so they are never +nil+.
    # This prevents race conditions in threaded environments (e.g. Puma, Sidekiq).
    clear_resolve_cache

    # Returns a readable representation used in errors.
    #
    # @return [String]
    def to_s
      return local unless namespace

      "{#{namespace}}#{local}"
    end
  }
end
