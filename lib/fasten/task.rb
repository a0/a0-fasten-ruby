module Fasten
  class Task < OpenStruct
    include Fasten::Logger

    def to_s
      name
    end
  end
end
