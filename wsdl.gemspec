# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "wsdl/version"

Gem::Specification.new do |s|
  s.name        = "wsdl"
  s.version     = WSDL::VERSION
  s.authors     = ["Daniel Harrington"]
  s.email       = ["me@rubiii.com"]
  s.homepage    = "https://github.com/rubiii/#{s.name}"
  s.summary     = "Rethinking WSDL"
  s.description = s.summary

  s.rubyforge_project = s.name

  s.add_dependency "nokogiri", ">= 1.4"

  s.add_development_dependency "rake",  "~> 0.9"
  s.add_development_dependency "rspec", "~> 2.7"
  s.add_development_dependency "mocha", "~> 0.10"
  s.add_development_dependency "guard-rspec"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
