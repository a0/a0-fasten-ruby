require 'forwardable'

module Fasten
  module UI
    class Console
      extend Forwardable

      def_delegators :runner, :workers, :tasks
      def_delegators :runner, :name, :jobs, :jobs=, :state, :state=, :hformat

      attr_accessor :runner

      def initialize(runner:)
        @runner = runner
        @old_done = []
        @old_failed = []
      end

      def setup
        puts <<~FIN

          = == === ==== ===== ====== ======= ======== ========= ==========
          Fasten your seatbelts! #{'💺' * jobs} #{runner.use_threads ? 'threads' : 'processes'}

          #{name}
        FIN

        $stdout.sync = true
        @setup_done = true
      end

      def update
        setup unless @setup_done

        display_task_message(tasks.done, @old_done, 'Done in')
        display_task_message(tasks.failed, @old_failed, 'Fail in')
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
          puts "Time: #{hformat Time.new - runner.ini} #{message} #{hformat task.dif} #{task.worker} Task #{task}"
          old << task
        end
      end
    end
  end
end
