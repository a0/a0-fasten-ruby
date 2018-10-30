module Fasten
  module State
    attr_accessor :error, :ini, :fin, :dif
    attr_writer :state

    def state
      @state || :IDLE
    end
  end
end
