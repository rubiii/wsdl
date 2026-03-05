# frozen_string_literal: true

module WSDL
  # Logging facade that provides a per-class logger to any object.
  #
  # Include this module to get an instance-level {#logger} method, and
  # a class-level {ClassMethods#logger logger} method via +extend+.
  #
  # Both loggers delegate to {WSDL.logger}, which defaults to a silent
  # {NullLogger}. Assign any +Logger+-compatible object to change the
  # output destination:
  #
  #   WSDL.logger = Rails.logger
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
    # A logger that silently discards all messages.
    #
    # Used as the default when no logger has been assigned via {WSDL.logger=}.
    class NullLogger
      # @return [nil]
      def debug(*); end

      # @return [nil]
      def info(*); end

      # @return [nil]
      def warn(*); end

      # @return [nil]
      def error(*); end

      # @return [nil]
      def fatal(*); end
    end

    # Returns the logger assigned to {WSDL.logger}.
    #
    # @return [Logger, NullLogger]
    def logger
      WSDL.logger
    end

    # @api private
    def self.included(base)
      base.extend(ClassMethods)
    end

    # Class-level logging methods, automatically extended when {Log} is included.
    module ClassMethods
      # Returns the logger assigned to {WSDL.logger}.
      #
      # @return [Logger, NullLogger]
      def logger
        WSDL.logger
      end
    end
  end
end
