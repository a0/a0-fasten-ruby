require 'fasten/support/state'

module Fasten
  class Task
    include Fasten::Support::State

    attr_accessor :name, :after, :shell, :ruby
    attr_accessor :dependants, :depends, :request, :response, :worker, :run_score, :block

    def initialize(name:, shell: nil, ruby: nil, block: nil, request: nil, after: nil)
      self.name = name
      self.shell = shell
      self.ruby = ruby
      self.block = block
      self.request = request
      self.after = after
    end

    def marshal_dump
      [@name, @state, @ini, @fin, @dif, @request, @response, @shell, @ruby, @block&.object_id, @error]
    end

    def marshal_load(data)
      @name, @state, @ini, @fin, @dif, @request, @response, @shell, @ruby, block_id, @error = data
      @block = ObjectSpace._id2ref block_id if block_id

      raise "Sorry, unable to get block for task #{self}, please try using threads" if block_id && !@block.is_a?(Proc)
    end

    def kind
      'task'
    end

    def to_s
      name
    end
  end
end
