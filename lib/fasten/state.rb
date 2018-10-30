module Fasten
  module State
    attr_accessor :error, :ini, :fin, :dif, :last
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
  end
end
