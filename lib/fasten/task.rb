module Fasten
  class Task < OpenStruct
    include Fasten::LogSupport

    def update_stats
      if state == :DONE
        Fasten::Stats.new(:done, self).add
      elsif state == :FAIL
        Fasten::Stats.new(:fail, self).add
      end
    end

    def to_s
      name
    end
  end
end
