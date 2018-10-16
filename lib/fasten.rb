# frozen_string_literal: true

require 'English'
require 'yaml'
require 'binding_of_caller'
require 'logger'
require 'ostruct'
require 'curses'
require 'fileutils'
require 'csv'

require 'fasten/log_support'
require 'fasten/stats'
require 'fasten/task'
require 'fasten/ui'
require 'fasten/dag'
require 'fasten/load_save'
require 'fasten/executor'
require 'fasten/worker'
require 'fasten/version'

module Fasten
  class << self
    include Fasten::LogSupport

    def load(path, **options)
      executor = Fasten::Executor.new(**options)
      executor.load(path)

      executor
    end
  end
end
