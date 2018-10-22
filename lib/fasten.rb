# frozen_string_literal: true

require 'English'
require 'yaml'
require 'binding_of_caller'
require 'logger'
require 'ostruct'
require 'curses'
require 'fileutils'
require 'csv'
require 'hirb'
require 'parallel'

require 'fasten/logger'
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
    include Fasten::Logger

    def load(path, **options)
      executor = Fasten::Executor.new(**options)
      executor.load(path)

      executor
    end

    def map(list, **options, &block)
      executor = Fasten::Executor.new(**options)
      executor.block = block

      list.each do |item|
        executor.add Fasten::Task.new name: item.to_s, request: item
      end

      executor.perform
      executor.stats_table

      executor.task_list.map(&:response)
    end
  end
end
