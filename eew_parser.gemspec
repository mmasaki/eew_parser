Gem::Specification.new do |spec|
  spec.name          = "eew_parser"
  spec.version       = "0.2.2"
  spec.authors       = ["Masaki Matsushita"]
  spec.email         = ["glass.saga@gmail.com"]
  spec.summary       = %q{Parser for Earthquake Early Warning from JMA}
  spec.description   = %q{Parser for Earthquake Early Warning from JMA}
  spec.homepage      = %q{https://github.com/mmasaki/eew_parser}
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.required_ruby_version = '>= 2.3.0'
  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 11.2"
  spec.add_development_dependency "rspec", "~> 3.7"
  spec.add_development_dependency "rspec-its", "~> 1.2"
end
