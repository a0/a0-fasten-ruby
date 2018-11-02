# frozen_string_literal: true

require 'fasten/task'
require 'fasten/runner'
require 'fasten/worker'
require 'fasten/version'

module Fasten
  class << self
    def runner_from_yaml(path, **options)
      runner = Fasten::Runner.new(**options)
      runner.load_yaml(path)

      runner
    end

    def map(list, **options, &block)
      Fasten::Runner.new(**options).map(list, &block)
    end
  end
end
