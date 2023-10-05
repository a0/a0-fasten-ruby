# frozen_string_literal: true

require_relative 'lib/fasten/version'

Gem::Specification.new do |spec|
  spec.name         = 'fasten'
  spec.version      = Fasten::VERSION
  spec.authors      = ['Aldrin Martoq']
  spec.email        = ['contacto@a0.cl']

  spec.summary      = 'Fasten your seatbelts! Run jobs in parallel, intelligently.'
  spec.description  = 'Fasten your seatbelts! Run jobs in parallel, intelligently.'
  spec.homepage     = 'https://github.com/a0/a0-fasten-ruby/'
  spec.license      = 'MIT'
  spec.required_ruby_version = '>= 3.2.0'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'

  spec.metadata['homepage_uri']     = spec.homepage
  spec.metadata['source_code_uri']  = spec.homepage
  spec.metadata['changelog_uri']    = 'https://github.com/a0/a0-fasten-ruby/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) || f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor])
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency 'example-gem', '~> 1.0'
  spec.add_dependency 'activesupport'
  spec.add_dependency 'binding_of_caller'
  spec.add_dependency 'tty-tree'

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
  spec.metadata['rubygems_mfa_required'] = 'true'
end
