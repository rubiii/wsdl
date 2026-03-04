# frozen_string_literal: true

require 'pathname'
require 'uri'

module WSDL
  # Classifies WSDL and schema locations.
  #
  # Supported location forms:
  # - HTTP(S) URL
  # - local file path (absolute or relative)
  #
  # @api private
  class Source
    class << self
      # Validates a WSDL source input and returns a classified source.
      #
      # @param value [Object] WSDL source input
      # @return [Source]
      # @raise [ArgumentError] when source is invalid
      def validate_wsdl!(value)
        unless value.is_a?(String) && !value.empty?
          raise ArgumentError, 'WSDL source must be a non-empty String URL or file path'
        end

        source = new(value)

        if source.inline_xml?
          raise ArgumentError,
                'Inline XML WSDL is not supported. Provide an HTTP(S) URL or a local file path.'
        end

        if source.file_url?
          raise ArgumentError,
                "file:// URLs are not supported: #{value.inspect}. " \
                'Provide an HTTP(S) URL or a local file path.'
        end

        if source.unsupported_scheme?
          raise ArgumentError,
                "Unsupported URL scheme for WSDL source #{value.inspect}. " \
                'Only HTTP(S) URLs and local file paths are supported.'
        end

        source
      end
    end

    # Pattern for matching HTTP/HTTPS URLs.
    HTTP_URL_PATTERN = /\Ahttps?:/i

    # Pattern for matching file:// URLs.
    FILE_URL_PATTERN = /\Afile:/i

    # Pattern for matching inline XML content.
    INLINE_XML_PATTERN = /\A\s*</

    # Pattern for matching URI schemes.
    URI_SCHEME_PATTERN = /\A[a-z][a-z0-9+\-.]*:/i

    # Pattern for matching Windows drive prefixes (e.g., C:foo or C:\foo).
    WINDOWS_DRIVE_PREFIX_PATTERN = /\A[A-Za-z]:/

    # Pattern for matching absolute Windows drive paths (e.g., C:\path or C:/path).
    WINDOWS_DRIVE_ABSOLUTE_PATTERN = %r{\A[A-Za-z]:[\\/]}

    # @param value [String] source location
    def initialize(value)
      @value = value
    end

    # @return [String]
    attr_reader :value

    # @return [Boolean]
    def url?
      @value.match?(HTTP_URL_PATTERN)
    end

    # @return [Boolean]
    def file_url?
      @value.match?(FILE_URL_PATTERN)
    end

    # @return [Boolean]
    def inline_xml?
      @value.match?(INLINE_XML_PATTERN)
    end

    # @return [Boolean]
    def file_path?
      !url? && !inline_xml? && !scheme?
    end

    # @return [Boolean]
    def absolute_file_path?
      return false unless file_path?

      Pathname.new(@value).absolute? || windows_drive_absolute_path?
    end

    # @return [Boolean]
    def relative_file_path?
      file_path? && !absolute_file_path?
    end

    # @return [Boolean]
    def unsupported_scheme?
      scheme? && !url? && !file_url?
    end

    # @return [String]
    def expanded_file_path
      File.expand_path(@value)
    end

    # @return [String]
    def sandbox_directory
      File.dirname(expanded_file_path)
    end

    # @return [String]
    def normalized_url
      URI.parse(@value).normalize.to_s
    rescue URI::InvalidURIError
      @value
    end

    # @return [Array<String>, nil]
    def default_sandbox_paths
      return nil if url?
      return [sandbox_directory] if file_path?

      nil
    end

    private

    # @return [Boolean]
    def scheme?
      return false if windows_drive_prefix?

      @value.match?(URI_SCHEME_PATTERN)
    end

    # @return [Boolean]
    def windows_drive_prefix?
      @value.match?(WINDOWS_DRIVE_PREFIX_PATTERN)
    end

    # @return [Boolean]
    def windows_drive_absolute_path?
      @value.match?(WINDOWS_DRIVE_ABSOLUTE_PATTERN)
    end
  end
end
