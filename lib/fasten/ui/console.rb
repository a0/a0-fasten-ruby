require 'forwardable'

module Fasten
  module UI
    class Console
      extend Forwardable

      def_delegators :runner, :worker_list, :task_list, :task_done_list, :task_error_list, :task_running_list, :task_waiting_list, :worker_list
      def_delegators :runner, :name, :workers, :workers=, :state, :state=, :hformat

      attr_accessor :runner

      def initialize(runner:)
        @runner = runner
        @old = {
          task_done_list: [],
          task_error_list: []
        }
      end

      def setup
        puts <<~FIN

          = == === ==== ===== ====== ======= ======== ========= ==========
          Fasten your seatbelts! #{'💺' * workers} #{runner.use_threads ? 'threads' : 'fork'}

          #{name}
        FIN

        $stdout.sync = true
        @setup_done = true
      end

      def update
        setup unless @setup_done
        display_task_message(task_done_list, @old[:task_done_list], 'Done in')
        display_task_message(task_error_list, @old[:task_error_list], 'Fail in')
      end

      def cleanup
        puts '========== ========= ======== ======= ====== ===== ==== === == ='
        @setup_done = false
      end

      def force_clear; end

      protected

      def display_task_message(orig, old, message)
        return unless old.count != orig.count

        (orig - old).each do |task|
          puts "Time: #{hformat Time.new - runner.ini} #{message} #{hformat task.dif} Task #{task}"
          old << task
        end
      end
    end
  end
end
