# frozen_string_literal: true

class WSDL
  class XS
    # Represents any unrecognized or generic XSD element.
    #
    # Used as a fallback when no specific type class is defined
    # for an XSD element type.
    #
    class AnyType < BaseType; end

    # Represents xs:complexContent for complex type derivation.
    class ComplexContent < BaseType; end

    # Represents xs:restriction for type restrictions.
    class Restriction < BaseType; end

    # Represents xs:all compositor (unordered elements, each appearing 0-1 times).
    class All < BaseType; end

    # Represents xs:sequence compositor (ordered elements).
    class Sequence < BaseType; end

    # Represents xs:choice compositor (one of several element alternatives).
    class Choice < BaseType; end

    # Represents xs:enumeration facet within a restriction.
    class Enumeration < BaseType; end
  end
end
