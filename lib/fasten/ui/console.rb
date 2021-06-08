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
          Fasten your seatbelts! #{'💺' * jobs} #{jobs} #{runner.use_threads ? 'threads' : 'processes'} #{tasks.count} tasks

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

        elapsed_str = hformat Time.new - runner.ini

        time_str = [elapsed_str, eta_str].compact.join(' ')

        (orig - old).each do |task|
          old << task
          puts "#{count_str(old.count, tasks.count)} Time: #{time_str} #{message} #{hformat task.dif} #{task.worker} Task #{task}"
        end
      end

      def count_str(count, total)
        len = total.to_s.length
        format "%#{len}d/%#{len}d", count, total
      end

      def eta_str
        @eta_str ||= begin
          @runner_last_avg = runner.last_avg
          if runner.last_avg && runner.last_err
            format 'ETA ≈ %s ± %.2f', hformat(runner.last_avg), runner.last_err
          elsif runner.last_avg
            format 'ETA ≈ %s', hformat(runner.last_avg)
          end
        end
      end
    end
  end
end
