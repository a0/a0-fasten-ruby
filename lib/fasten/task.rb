module Fasten
  class Task
    include Fasten::Logger
    include Fasten::State

    attr_accessor :name, :after, :shell, :ruby
    attr_accessor :dependants, :depends, :request, :response, :worker, :run_score

    def initialize(name: nil, shell: nil, ruby: nil, request: nil, after: nil)
      self.name = name
      self.after = after
      self.shell = shell
      self.ruby = ruby
      self.request = request
    end

    def marshal_dump
      [@name, @state, @ini, @fin, @dif, @request, @response, @shell, @ruby, @error]
    end

    def marshal_load(data)
      @name, @state, @ini, @fin, @dif, @request, @response, @shell, @ruby, @error = data
    end

    def to_s
      name
    end
  end
end
