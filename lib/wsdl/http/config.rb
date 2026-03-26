# frozen_string_literal: true

require 'openssl'

module WSDL
  module HTTP
    # Default open (connection) timeout in seconds.
    DEFAULT_OPEN_TIMEOUT = 30

    # Default write (send) timeout in seconds.
    DEFAULT_WRITE_TIMEOUT = 60

    # Default read (receive) timeout in seconds.
    DEFAULT_READ_TIMEOUT = 120

    # Default maximum number of redirects to follow.
    # Prevents redirect loops and excessive redirect chains.
    DEFAULT_REDIRECT_LIMIT = 5

    # Holds timeout, SSL, and redirect settings applied to each +Net::HTTP+ request.
    #
    # @example
    #   config = WSDL::HTTP::Config.new
    #   config.open_timeout = 10
    #   config.read_timeout = 60
    #   config.ca_file = '/path/to/ca-bundle.crt'
    class Config
      # @return [Integer] connection timeout in seconds
      attr_accessor :open_timeout

      # @return [Integer] write timeout in seconds
      attr_accessor :write_timeout

      # @return [Integer] read timeout in seconds
      attr_accessor :read_timeout

      # @return [Integer] maximum number of redirects to follow
      attr_accessor :max_redirects

      # @return [Integer] SSL verification mode (e.g. +OpenSSL::SSL::VERIFY_PEER+)
      attr_accessor :verify_mode

      # @return [String, nil] path to a CA certificate file
      attr_accessor :ca_file

      # @return [String, nil] path to a directory of CA certificates
      attr_accessor :ca_path

      # @return [OpenSSL::X509::Certificate, nil] client certificate for mutual TLS
      attr_accessor :cert

      # @return [OpenSSL::PKey::PKey, nil] client private key for mutual TLS
      attr_accessor :key

      # @return [Symbol, nil] minimum SSL/TLS version (e.g. +:TLS1_2+)
      attr_accessor :min_version

      # @return [Symbol, nil] maximum SSL/TLS version
      attr_accessor :max_version

      # Creates a new Config with secure defaults.
      def initialize
        @open_timeout = DEFAULT_OPEN_TIMEOUT
        @write_timeout = DEFAULT_WRITE_TIMEOUT
        @read_timeout = DEFAULT_READ_TIMEOUT
        @max_redirects = DEFAULT_REDIRECT_LIMIT
        @verify_mode = OpenSSL::SSL::VERIFY_PEER
      end
    end
  end
end
