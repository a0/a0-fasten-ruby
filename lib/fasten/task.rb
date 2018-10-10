module Fasten
  class Task < OpenStruct
    include Fasten::LogSupport

    def to_s
      name
    end
  end
end
