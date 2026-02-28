# -*- encoding : utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$:.unshift lib unless $:.include? lib

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

  # TODO: get rid of Nori.
  s.add_dependency 'nori',     '~> 2.2.0'

  s.add_dependency 'nokogiri',   '>= 1.4.0'
  s.add_dependency 'builder',    '>= 3.0.0'
  s.add_dependency 'httpclient', '~> 2.3'
  s.add_dependency 'logging',    '~> 1.8'

  s.add_development_dependency 'rake',  '~> 12.3'
  s.add_development_dependency 'rspec', '~> 3'
  s.add_development_dependency 'mocha', '~> 0.14'
  s.add_development_dependency 'equivalent-xml', '~> 0.3'

  ignores  = File.readlines('.gitignore').grep(/\S+/).map(&:chomp)
  dotfiles = %w[.gitignore .yardopts]

  all_files_without_ignores = Dir['**/*'].reject { |f|
    File.directory?(f) || ignores.any? { |i| File.fnmatch(i, f) }
  }

  s.files = (all_files_without_ignores + dotfiles).sort

  s.require_path = 'lib'
end
