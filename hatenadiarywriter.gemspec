# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'hatenadiarywriter/version'

Gem::Specification.new do |spec|
  spec.name          = "hatenadiarywriter"
  spec.version       = HatenaDiaryWriter::VERSION
  spec.authors       = ["arikui1911"]
  spec.email         = ["arikui.ruby@gmail.com"]

  # if spec.respond_to?(:metadata)
  #   spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com' to prevent pushes to rubygems.org, or delete to allow pushes to any server."
  # end

  spec.summary       = %q{`Hatena diary writer'(http://www.hyuki.com/techinfo/hatena_diary_writer.html) in Ruby.}
  spec.homepage      = "https://github.com/arikui1911/hatenadiarywriter"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.8"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "test-unit", "~> 0"

  spec.add_runtime_dependency "hatenadiary", "~> 0"
  spec.add_runtime_dependency "levenshtein", "~> 0"
end
