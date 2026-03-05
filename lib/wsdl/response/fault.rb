# frozen_string_literal: true

module WSDL
  class Response
    # Represents a parsed SOAP fault from a response.
    #
    # Handles both SOAP 1.1 and 1.2 fault structures, normalizing
    # them into a consistent interface.
    #
    # SOAP 1.1 structure:
    #   <soap:Fault>
    #     <faultcode>soap:Server</faultcode>
    #     <faultstring>Something went wrong</faultstring>
    #     <faultactor>http://example.com/actor</faultactor>
    #     <detail><Error>details</Error></detail>
    #   </soap:Fault>
    #
    # SOAP 1.2 structure:
    #   <soap:Fault>
    #     <soap:Code>
    #       <soap:Value>soap:Receiver</soap:Value>
    #       <soap:Subcode>
    #         <soap:Value>app:DatabaseError</soap:Value>
    #       </soap:Subcode>
    #     </soap:Code>
    #     <soap:Reason><soap:Text xml:lang="en">Something went wrong</soap:Text></soap:Reason>
    #     <soap:Node>http://example.com/node</soap:Node>
    #     <soap:Role>http://example.com/role</soap:Role>
    #     <soap:Detail><Error>details</Error></soap:Detail>
    #   </soap:Fault>
    #
    # @example Accessing fault information
    #   fault = response.fault
    #   fault.code      # => "soap:Server" (1.1) or "env:Receiver" (1.2)
    #   fault.subcodes  # => [] (1.1) or ["app:DatabaseError"] (1.2)
    #   fault.reason    # => "Something went wrong"
    #   fault.detail    # => { Error: "details" }
    #   fault.node      # => nil (1.1) or "http://example.com/node" (1.2)
    #   fault.role      # => "http://example.com/actor" (1.1 faultactor) or role (1.2)
    #
    # @!attribute [r] code
    #   @return [String, nil] the fault code (faultcode in 1.1, Code/Value in 1.2)
    # @!attribute [r] subcodes
    #   @return [Array<String>] nested subcodes (SOAP 1.2 only, empty for 1.1)
    # @!attribute [r] reason
    #   @return [String, nil] the fault reason (faultstring in 1.1, Reason/Text in 1.2)
    # @!attribute [r] detail
    #   @return [Hash, nil] parsed fault detail children, or nil if absent
    # @!attribute [r] node
    #   @return [String, nil] URI of the SOAP node that generated the fault (SOAP 1.2 only)
    # @!attribute [r] role
    #   @return [String, nil] role/actor (faultactor in 1.1, Role in 1.2)
    Fault = Data.define(:code, :subcodes, :reason, :detail, :node, :role) {
      # Returns a human-readable summary of the fault.
      #
      # @return [String] fault summary
      def to_s
        message = "(#{code}) #{reason}"
        message << " [role: #{role}]" if role
        message
      end
    }
  end
end
