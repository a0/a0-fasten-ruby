# frozen_string_literal: true

module Fasten
  class << self
    def default_name
      File.basename(Dir.getwd)
    end

    def default_stats
      true
    end

    def default_summary
      false
    end

    def default_jobs
      Parallel.physical_processor_count
    end

    def default_worker_class
      Worker
    end

    def default_fasten_dir
      'fasten'
    end

    def default_use_threads
      !OS.posix?
    end

    def default_ui_mode
      return @default_ui_mode if defined? @default_ui_mode

      require 'fasten/ui/curses'

      @default_ui_mode = STDIN.tty? && STDOUT.tty? ? :curses : :console
    rescue StandardError, LoadError
      @default_ui_mode = :console
    end

    def default_developer
      STDIN.tty? && STDOUT.tty?
    end

    def default_priority
      :dependants
    end
  end
end
