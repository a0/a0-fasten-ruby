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
      runner(**options).map(list, &block)
    end

    def runner(**options)
      @runner ||= Fasten::Runner.new(**options)
    end

    def cleanup
      @runner = nil
    end

    def reconfigure(**options)
      runner.reconfigure(**options)
    end

    def register(**options, &block)
      runner(**options).register(&block)
    end
  end
end
