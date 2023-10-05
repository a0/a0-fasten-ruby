# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext'
require 'active_support/time'
require 'tty-tree'
require 'yaml'
require 'English'

require_relative 'fasten/support/logger'
require_relative 'fasten/support/state'

require_relative 'fasten/runner'
require_relative 'fasten/std_thread_proxy'
require_relative 'fasten/task'
require_relative 'fasten/worker'
require_relative 'fasten/version'

module Fasten
  class Error < StandardError; end

  def self.runner(...)
    Fasten::Runner.new(...)
  end

  DEFAULT_FASTEN_DIR = '.fasten'
end
