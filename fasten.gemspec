lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fasten/version'

Gem::Specification.new do |spec|
  spec.name          = 'fasten'
  spec.version       = Fasten::VERSION
  spec.authors       = ['Aldrin Martoq']
  spec.email         = ['contacto@a0.cl']

  spec.summary       = 'Fasten your seatbelts! Run jobs in parallel, intelligently.'
  spec.description   = 'Fasten your seatbelts! Run jobs in parallel, intelligently.'
  spec.homepage      = 'https://github.com/a0/fasten/'
  spec.license       = 'MIT'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.16'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop'

  spec.add_runtime_dependency 'binding_of_caller'
  spec.add_runtime_dependency 'curses'

  raise 'RubyGems 2.0 or newer is required to protect against public gem pushes.' unless spec.respond_to?(:metadata)

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'
end
