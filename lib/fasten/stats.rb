module Fasten
  class Stats
    def initialize(name, target)
      @name = name
      @target = target
      @target.stats ||= {}
      @target.stats[@name] ||= {}
      @target.stats[@name][:his] ||= []
    end

    def add
      return unless @target.ini && @target.fin

      time = @target.fin - @target.ini
      @target.stats[@name][:his] << [Time.new, time]

      times = @target.stats[@name][:his].map(&:last)
      @target.stats[@name][:avg] = times.inject(0.0) { |s, x| s + x } / times.size
      @target.stats[@name][:std] = Math.sqrt(times.inject(0.0) { |v, x| v + (x - @target.stats[@name][:avg])**2 })
    end
  end
end
