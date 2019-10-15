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

      def last
        return @last if defined? @last

        return {} unless @runner

        @last = runner.stats_last(self)
      end

      def last_avg
        @last_avg ||= last['avg']&.to_f
      end

      def last_err
        @last_err ||= last['err']&.to_f
      end
    end
  end
end
