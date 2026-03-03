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
  s.description = 'Turn WSDL documents into inspectable services and callable operations'
  s.required_ruby_version = '>= 3.2'

  s.license = 'MIT'

  s.add_dependency 'base64'
  s.add_dependency 'logging',  '>= 2.4'
  s.add_dependency 'nokogiri', '>= 1.19'

  ignores  = File.readlines('.gitignore').grep(/\S+/).map(&:chomp)
  dotfiles = %w[.gitignore .yardopts]

  all_files_without_ignores = Dir['**/*'].reject { |f|
    File.directory?(f) || ignores.any? { |i| File.fnmatch(i, f) }
  }

  s.files = (all_files_without_ignores + dotfiles).sort

  s.require_path = 'lib'
  s.metadata['rubygems_mfa_required'] = 'true'
end
