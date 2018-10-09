module Fasten
  class Task < OpenStruct
    include Fasten::LogSupport
    def initialize(*)
      super
    end

    def perform
      log_debug "Performing #{self}"
      system shell if shell
    end

    def to_s
      name
    end
  end
end
