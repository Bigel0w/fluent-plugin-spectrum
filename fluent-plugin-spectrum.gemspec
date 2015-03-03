# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |gem|
  gem.name          = "fluent-plugin-spectrum"
  gem.version       = "0.0.3"
  gem.date          = '2015-02-24'
  gem.authors       = ["Alex Pena"]
  gem.email         = ["alex_pena@intuit.com"]
  gem.summary       = %q{Fluentd input plugin for Spectrum Alerts}
  gem.description   = %q{Fluentd plugin for Spectrum Alerts... WIP}
  gem.homepage      = 'https://github.com/Bigel0w/fluent-plugin-spectrum'
  gem.license       = 'MIT'

  gem.files         = `git ls-files`.split($\)
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.require_paths = ["lib"]

  gem.add_development_dependency "rake", '~> 0.9', '>= 0.9.6'

  gem.add_runtime_dependency "fluentd", '~> 0.10', '>= 0.10.52'
  gem.add_runtime_dependency "json", '~> 1.1', '>= 1.8.2'
  gem.add_runtime_dependency "rest-client", '~> 1.7', '>= 1.7.3'
end