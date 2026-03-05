# frozen_string_literal: true

require 'logging'

module WSDL
  # Logging facade that provides a per-class logger to any object.
  #
  # Include this module to get an instance-level {#logger} method, and
  # a class-level {ClassMethods#logger logger} method via +extend+.
  #
  # Both loggers are lazily created via the +logging+ gem and are
  # named after the including class (e.g. +"WSDL::XML::Parser"+).
  #
  # @example Instance logging
  #   class MyService
  #     include WSDL::Log
  #
  #     def call
  #       logger.info('processing request')
  #     end
  #   end
  #
  # @example Class-level logging
  #   class MyParser
  #     include WSDL::Log
  #
  #     def self.parse(xml)
  #       logger.debug('parsing started')
  #     end
  #   end
  #
  module Log
    # Returns the root logger for the WSDL namespace.
    #
    # @return [Logging::Logger]
    def self.root
      @root ||= Logging.logger[WSDL]
    end

    # Returns a logger named after the receiver's class.
    #
    # @return [Logging::Logger]
    def logger
      @logger ||= Logging.logger[self.class]
    end

    # @api private
    def self.included(base)
      base.extend(ClassMethods)
    end

    # Class-level logging methods, automatically extended when {Log} is included.
    module ClassMethods
      # Returns a logger named after the class or module.
      #
      # @return [Logging::Logger]
      def logger
        @logger ||= Logging.logger[self]
      end
    end
  end
end
