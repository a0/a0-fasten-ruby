# frozen_string_literal: true

require 'English'
require 'yaml'
require 'binding_of_caller'
require 'logger'
require 'ostruct'

require 'fasten/log_support'
require 'fasten/task'
require 'fasten/dag'
require 'fasten/executor'
require 'fasten/version'

module Fasten
  class << self
    include Fasten::LogSupport

    def load(path, **options)
      executor = Fasten::Executor.new(**options)

      YAML.safe_load(File.read(path)).each do |name, params|
        params.each do |key, val|
          next unless val.is_a?(String) && (match = %r{^/(.+)/$}.match(val))

          params[key] = Regexp.new(match[1])
        end
        executor.add Fasten::Task.new({ name: name }.merge(params))
      end

      log_info "Loaded #{executor.dag.tasks.count} tasks from #{path}"
      executor
    end
  end
end
