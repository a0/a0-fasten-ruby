require 'English'
require 'fasten/support/logger'
require 'fasten/support/state'
require 'fasten/support/fork_worker'
require 'fasten/support/thread_worker'

module Fasten
  class WorkerError < StandardError
    attr_reader :backtrace

    def initialize(origin)
      super "#{origin.class} #{origin.message}"
      @backtrace = origin.backtrace
    end
  end

  class Worker
    include Fasten::Support::Logger
    include Fasten::Support::State

    attr_accessor :runner, :name, :spinner, :child_read, :child_write, :parent_read, :parent_write, :block, :running_task

    def initialize(runner:, name: nil, use_threads: nil)
      if use_threads
        extend Fasten::Support::ThreadWorker
      else
        extend Fasten::Support::ForkWorker
      end

      self.runner = runner
      self.name = name
      self.spinner = 0

      initialize_logger(log_file: runner&.log_file)
    end

    def perform(task)
      perform_shell(task) if task.shell
      perform_ruby(task) if task.ruby
      perform_block(task) if block
    end

    def kind
      'worker'
    end

    def to_s
      name
    end

    protected

    def perform_ruby(task)
      task.response = eval task.ruby # rubocop:disable Security/Eval we trust our users ;-)
    end

    def perform_shell(task)
      result = system task.shell

      raise "Command failed with exit code: #{$CHILD_STATUS.exitstatus}" unless result
    end

    def perform_block(task)
      task.response = block.call(task.request)
    end

    def process_incoming_requests
      log_ini self, 'process_incoming_requests'

      while (object = receive_request_from_parent)
        run_task(object) if object.is_a? Fasten::Task
      end

      log_fin self, 'process_incoming_requests'
    rescue EOFError
      log_info 'Terminating on EOF'
    end

    def run_task(task)
      log_ini task, 'run_task'
      redirect_std "#{runner.fasten_dir}/log/task/#{task.name}.log"

      perform_task task
    ensure
      restore_std
      logger.reopen(log_file)
      log_fin task, 'run_task'
    end

    def perform_task(task)
      log_ini task, 'perform_task'

      perform(task)
      task.state = :DONE
    rescue StandardError => error
      task.state = :FAIL
      task.error = WorkerError.new(error)
    ensure
      log_fin task, 'perform_task'
      send_response_to_parent(task)
    end
  end
end
