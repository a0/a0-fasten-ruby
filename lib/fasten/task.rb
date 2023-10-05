# frozen_string_literal: true

module Fasten
  class Task
    include ::Fasten::Support::State

    attr_accessor :name, :worker_class, :after, :data, :block, :result, :error, :depends, :dependants, :score

    def initialize(name:, worker_class:, after: nil, data: nil, block: nil)
      @name = name
      @worker_class = worker_class
      @after = after
      @data = data
      @block = block
      @score = 0
      @dependants = []
      @depends = []
    end

    def to_s
      as_json
    end
  end
end
