# frozen_string_literal: true

require 'wsdl/http/response'
require 'wsdl/http/client'

module WSDL
  # HTTP client and response types for fetching WSDL documents and
  # invoking SOAP operations.
  #
  # The built-in {Client} uses Ruby's stdlib +net/http+ with secure
  # defaults. Custom clients can be plugged in via {WSDL.http_client=}
  # as long as they respond to +get+ and +post+ and return
  # {Response} instances.
  #
  # @see file:docs/core/http-client.md HTTP Client Guide
  #
  module HTTP
  end
end
