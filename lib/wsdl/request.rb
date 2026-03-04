# frozen_string_literal: true

module WSDL
  # Request AST, DSL, validation and serialization pipeline.
  module Request
    require 'wsdl/request/names'
    require 'wsdl/request/ast'
    require 'wsdl/request/dsl_context'
    require 'wsdl/request/validator'
    require 'wsdl/request/security_conflict_detector'
    require 'wsdl/request/serializer'
    require 'wsdl/request/rpc_wrapper'
  end
end
