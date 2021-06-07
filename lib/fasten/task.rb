require 'fasten/support/state'

module Fasten
  class Task
    include Fasten::Support::State

    attr_accessor :name, :after, :shell, :ruby, :worker_class, :dependants, :depends, :request, :response, :worker, :run_score, :weight, :block

    def initialize(name:, shell: nil, ruby: nil, block: nil, request: nil, after: nil, weight: 1, worker_class: nil)
      self.name = name
      self.shell = shell
      self.ruby = ruby
      self.block = block
      self.request = request
      self.after = after
      self.weight = weight
      self.worker_class = worker_class

      # ObjectSpace.define_finalizer(self) do
      #   puts "I am dying! pid: #{Process.pid} thread: #{Thread.current} TASK #{@name}"
      # end

      block&.object_id
      # block && begin

      #   # puts "block_id: #{block.object_id} for task #{@name}"
      # end

      # block && ObjectSpace.define_finalizer(block) do
      #   puts "I am dying! pid: #{Process.pid} thread: #{Thread.current} TASK #{@name} BLOCK"
      # end
    end

    def marshal_dump
      [@name, @state, @ini, @fin, @dif, @request, @response, @shell, @ruby, @block&.object_id, @error]
    end

    def marshal_load(data)
      @name, @state, @ini, @fin, @dif, @request, @response, @shell, @ruby, block_id, @error = data
      @block = begin
        ObjectSpace._id2ref block_id.to_i if block_id
      rescue StandardError
        # pass
      end

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
