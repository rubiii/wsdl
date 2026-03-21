# frozen_string_literal: true

module WSDL
  module TestService
    # RSpec integration for {TestService}.
    #
    # Provides the +:test_service+ metadata tag that enables real HTTP
    # connections for live mock service tests, and registers an
    # +after(:suite)+ hook to shut down the shared {MockServer}.
    #
    # Auto-configured when this file is loaded — no manual setup needed.
    #
    # @example Tag a context to enable live HTTP
    #   context 'with a live mock service', :test_service do
    #     before { service.start }
    #     # ...
    #   end
    #
    module SpecHelpers
      def self.install!(config)
        config.around(:example, :test_service) do |example|
          WebMock.allow_net_connect!(net_http_connect_on_start: true)
          example.run
        ensure
          WebMock.disable_net_connect!
        end

        config.after(:suite) do
          MockServer.reset!
        end
      end
    end
  end
end

RSpec.configure do |config|
  WSDL::TestService::SpecHelpers.install!(config)
end
