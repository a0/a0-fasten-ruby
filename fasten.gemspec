require_relative 'lib/fasten/version'
require 'os'

Gem::Specification.new do |spec|
  spec.name          = 'fasten'
  spec.version       = Fasten::VERSION
  spec.authors       = ['Aldrin Martoq']
  spec.email         = ['contacto@a0.cl']

  spec.summary       = 'Fasten your seatbelts! Run jobs in parallel, intelligently.'
  spec.description   = 'Fasten your seatbelts! Run jobs in parallel, intelligently.'
  spec.homepage      = 'https://github.com/a0/a0-fasten-ruby/'
  spec.license       = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 2.6.0')

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/a0/a0-fasten-ruby/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features|demo)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'curses' unless OS.windows?
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'rubocop-rake'
  spec.add_development_dependency 'rubocop-rspec'

  spec.add_runtime_dependency 'binding_of_caller'
  spec.add_runtime_dependency 'hirb'
  spec.add_runtime_dependency 'os'
  spec.add_runtime_dependency 'parallel'
end
