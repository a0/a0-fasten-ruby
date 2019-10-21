module Fasten
  class TaskManager < Array # rubocop:disable Metrics/ClassLength
    attr_reader :done, :failed, :pending, :running, :targets, :runner

    def initialize(targets: [], runner:)
      super()

      @map = {}
      @done = []
      @failed = []
      @pending = []
      @running = []
      @targets = targets
      @waiting = nil
      @runner = runner
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
        failed << task
      end
    end

    def waiting
      return @waiting if @waiting

      reset
      setup_dependencies
      setup_targets
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

    def setup_targets
      return if @targets.empty?

      @targets.each do |target|
        task = target.is_a?(Task) ? target : @map[target]
        raise "Target task #{target} not found" unless task

        mark_needed(task)
      end

      @pending.reject { |task| task.state == :NEED }.each do |task|
        @pending.delete task
        delete task
      end

      @pending.each do |task|
        task.state = nil
      end
    end

    def mark_needed(task)
      return unless task.state == :IDLE

      task.state = :NEED
      task.depends.each do |depend_task|
        mark_needed(depend_task)
      end
    end

    def setup_scores
      each do |task|
        task.run_score = task.dependants.count
      end
    end

    def move_pending_to_waiting
      to_move = pending.select { |task| task.depends.count.zero? }

      @pending -= to_move
      @waiting += to_move
      case @runner.priority
      when :dependants
        @waiting.sort_by!.with_index do |task, index|
          task.state = :WAIT
          [-task.run_score, index]
        end
      when :dependants_avg
        @waiting.sort_by!.with_index do |task, index|
          task.state = :WAIT
          last_avg = task.last_avg || 0
          [-task.run_score, -last_avg, index]
        end
      else
        raise "Unknown priority #{@runner.priority}"
      end
    end
  end
end
