require 'forwardable'

module Fasten
  module UI
    class Console
      extend Forwardable
      def_delegators :executor, :worker_list, :task_list, :task_done_list, :task_error_list, :task_running_list, :task_waiting_list, :worker_list
      def_delegators :executor, :name, :workers, :workers=, :state, :state=

      attr_accessor :executor

      def initialize(executor:)
        @executor = executor
        @old = {
          task_done_list: [],
          task_error_list: []
        }
      end

      def setup
        puts <<~FIN

          = == === ==== ===== ====== ======= ======== ========= ==========
          Fasten your seatbelts! #{'💺' * workers}

          #{name}
        FIN

        $stdout.sync = true
        @setup_done = true
      end

      def update
        setup unless @setup_done
        display_task_message(task_done_list, :task_done_list, 'Done  in')
        display_task_message(task_error_list, :task_error_list, 'Error in')
      end

      def cleanup
        puts '========== ========= ======== ======= ====== ===== ==== === == ='
        @setup_done = false
      end

      def force_clear; end

      protected

      def display_task_message(orig, name, message)
        old = @old[name]
        return unless old.count != orig.count

        (orig - old).each do |task|
          puts "Time: #{executor.hformat Time.new - executor.ini} #{message} #{executor.hformat task.dif} Task #{task} #{task.dif}"
          @old[name] << task
        end
      end
    end
  end
end
