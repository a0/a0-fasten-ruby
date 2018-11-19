module Fasten
  class TaskManager < Array
    attr_reader :done, :failed, :pending, :running, :targets

    def initialize(targets: nil)
      super()

      @map = {}
      @done = []
      @failed = []
      @pending = []
      @running = []
      @targets = targets
      @waiting = nil
    end

    def push(*items)
      items.each do |item|
        self << item
      end

      self
    end

    def <<(task)
      raise "Object class #{task.class} not allowed" unless task.is_a? Task
      raise "Task '#{task.name}' already defined" if @map[task.name]

      @map[task.name] = task
      @waiting = nil
      super
    end

    def next
      waiting.shift
    end

    def update(task)
      pending.delete task

      if task.state == :DONE
        done << task
        task.dependants.each { |dependant_task| dependant_task.depends.delete task }

        move_pending_to_waiting
      else
        error << task
      end
    end

    def waiting
      return @waiting if @waiting

      reset
      setup_dependencies
      setup_scores
      move_pending_to_waiting
    end

    def no_waiting?
      waiting.empty?
    end

    def no_running?
      running.empty?
    end

    def waiting?
      !waiting.empty?
    end

    def running?
      !running.empty?
    end

    def failed?
      !failed.empty?
    end

    protected

    def reset
      by_state = group_by(&:state)

      @done = by_state.delete(:DONE) || []
      @failed = by_state.delete(:FAIL) || []
      @running = by_state.delete(:RUNNING) || []
      @waiting = []

      return unless @targets.nil? || @targets.empty?

      @pending = by_state.values.flatten.each do |task|
        task.depends = []
        task.dependants = []
        task.state = nil
      end
    end

    def setup_dependencies
      @pending.each do |task|
        next unless task.after

        [task.after].flatten.each do |after|
          after_task = after.is_a?(Task) ? after : @map[after]
          raise "Dependency task '#{after}' not found on task '#{task.name}'." unless after_task

          task.depends << after_task
          after_task.dependants << task
        end
      end
    end

    def setup_scores
      @pending.each do |task|
        task.run_score = task.dependants.count
      end
    end

    def move_pending_to_waiting
      to_move = pending.select { |task| task.depends.count.zero? }

      @pending -= to_move
      @waiting += to_move
      @waiting.sort_by!.with_index do |x, index|
        x.state = :WAIT
        [-x.run_score, index]
      end
    end
  end
end
