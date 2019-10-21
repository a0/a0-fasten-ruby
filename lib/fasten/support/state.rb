require 'digest'

module Fasten
  module Support
    module State
      attr_accessor :error, :ini, :fin, :dif, :runner
      attr_writer :state

      def state
        @state || :IDLE
      end

      def running?
        state == :RUNNING
      end

      def idle?
        state == :IDLE
      end

      def pausing?
        state == :PAUSING
      end

      def paused?
        state == :PAUSED
      end

      def quitting?
        state == :QUITTING
      end

      def last_stat
        return @last_stat if defined? @last_stat

        return {} unless @runner

        @last_stat = runner.stats_last(self)
      end

      def last_avg
        @last_avg ||= last_stat['avg']
      end

      def last_err
        @last_err ||= last_stat['err']
      end

      def deps
        return @deps if defined? @deps

        str = deps_str

        @deps = str && Digest::SHA1.hexdigest(str)
      end

      def deps_str
        if is_a? Fasten::Task
          if after.is_a? Array
            after.sort_by do |task|
              task.is_a?(Fasten::Task) ? task.name : task
            end&.join(', ')
          else
            after
          end
        elsif is_a? Fasten::Runner
          tasks.sort_by(&:name).map do |task|
            [task.name, task.deps_str].compact.join(': ')
          end.join("\n")
        end
      end
    end
  end
end
