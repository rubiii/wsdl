# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift lib unless $LOAD_PATH.include? lib

require 'wsdl/version'

Gem::Specification.new do |s|
  s.name        = 'wsdl'
  s.version     = WSDL::VERSION
  s.authors     = ['Daniel Harrington']
  s.email       = 'me@rubiii.com'
  s.homepage    = 'https://github.com/rubiii/wsdl'
  s.summary     = 'WSDL toolkit for Ruby'
  s.description = 'Turn WSDL 1.1 documents into inspectable services and callable operations'
  s.required_ruby_version = '>= 3.3'

  s.license = 'MIT'

  s.add_dependency 'base64'
  s.add_dependency 'nokogiri', '>= 1.19.1'

  ignores  = File.readlines('.gitignore').grep(/\S+/).map(&:chomp)
  dotfiles = %w[.gitignore .yardopts]

  all_files_without_ignores = Dir['**/*'].reject { |f|
    File.directory?(f) || ignores.any? { |i| File.fnmatch(i, f) }
  }

  s.files = (all_files_without_ignores + dotfiles).sort

  s.require_path = 'lib'
  s.metadata['rubygems_mfa_required'] = 'true'
  s.metadata['source_code_uri']      = 'https://github.com/rubiii/wsdl'
  s.metadata['changelog_uri']        = 'https://github.com/rubiii/wsdl/blob/main/CHANGELOG.md'
  s.metadata['bug_tracker_uri']      = 'https://github.com/rubiii/wsdl/issues'
  s.metadata['documentation_uri']    = 'https://rubydoc.info/gems/wsdl'
end
