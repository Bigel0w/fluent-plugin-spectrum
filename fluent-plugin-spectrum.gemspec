# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |gem|
  gem.name          = "fluent-plugin-spectrum"
  gem.version       = "0.0.6"
  gem.date          = '2015-04-04'
  gem.authors       = ["Alex Pena"]
  gem.email         = ["pena.alex@gmail.com"]
  gem.summary       = %q{Fluentd plugin for managing monitoring alerts from CA Spectrum}
  gem.description   = %q{Fluentd input/output plugin for managing monitoring alerts from CA Spectrum. Input supports polling CA Spectrum APIs. Output currently only supports updating events retrieved from Spectrum.}
  gem.homepage      = 'https://github.com/Bigel0w/fluent-plugin-spectrum'
  gem.license       = 'MIT'

  gem.files         = `git ls-files`.split($\)
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.require_paths = ["lib"]
  # dev deps
  gem.add_development_dependency "rake", '~> 10.0'
  gem.add_development_dependency "bundler", '~> 1.6'
  gem.add_development_dependency "test-unit", '~> 3.0'
  gem.add_development_dependency "codeclimate-test-reporter", '~> 0.4'

  # runtime deps
  gem.add_runtime_dependency "fluentd", '~> 0.12'
  gem.add_runtime_dependency "json", '~> 1.8'
  gem.add_runtime_dependency "rest-client", '~> 1.8'
end