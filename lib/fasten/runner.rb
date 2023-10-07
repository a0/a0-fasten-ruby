# frozen_string_literal: true

module Fasten
  class Runner
    include ::Fasten::Support::Logger
    include ::Fasten::Support::State

    attr_accessor :task_list
    attr_reader :fasten_dir

    def initialize(name: File.basename(Dir.getwd), default_worker_class: ::Fasten::Worker, fasten_dir: ::Fasten::DEFAULT_FASTEN_DIR)
      @name = name
      @default_worker_class = default_worker_class

      @fasten_dir = fasten_dir

      @worker_instance_map = {}

      @task_list = []
      @task_map = {}
      @task_list_monitor = Monitor.new

      state_pend!
      initialize_logger
      log_ini self, '** CREATED **'
    end

    def [](key)
      @task_map[key]
    end

    def task(name, **opts, &block)
      raise "Invalid name '#{name}' (#{name.class})" unless name.present?
      raise "Name '#{name}' already defined" if @task_map[name]

      opts[:name] = name
      opts[:block] = block
      opts[:worker_class] ||= @default_worker_class

      @task_list_monitor.synchronize do
        # will force to recalculate dependencies
        @exec_list = @deps_list = @pend_list = nil

        @task_list << (created_task = Task.new(**opts))

        @task_map[name] = created_task
      end
    end

    def pend_list = @pend_list || calculate_deps(return_list: :pend_list)
    def deps_list = @deps_list || calculate_deps(return_list: :deps_list)
    def exec_list = @exec_list || calculate_deps(return_list: :exec_list)
    def done_list = @done_list || calculate_deps(return_list: :done_list)
    def fail_list = @fail_list || calculate_deps(return_list: :fail_list)

    def calculate_deps(return_list: nil)
      @task_list_monitor.synchronize do
        by_state = task_list.group_by(&:state)
        @exec_list = by_state.delete(:EXEC) || []
        @done_list = by_state.delete(:DONE) || []
        @fail_list = by_state.delete(:FAIL) || []

        @candidate_map = {}
        candidates = by_state.values.flatten.each do |candidate_task|
          candidate_task.depends = []
          candidate_task.dependants = []
        end

        candidates.each do |candidate_task|
          next unless candidate_task.after

          [candidate_task.after].flatten.each do |after|
            raise "Dependency task '#{after}' not found for task '#{candidate_task.name}'." unless (after_task = @task_map[after])

            candidate_task.depends << after
            after_task.dependants << candidate_task.name
          end
        end

        candidates.sort_by!.with_index do |candidate_task, index|
          candidate_task.score = candidate_task.dependants.count
          candidate_task.depends.count.zero? ? candidate_task.state_pend! : candidate_task.state_deps!

          [-candidate_task.score, index]
        end

        @pend_list, @deps_list = candidates.partition(&:pend?)

        instance_variable_get("@#{return_list}") if return_list
      end
    end

    def puts_tree = puts render_tree
    def render_tree = TTY::Tree.new(tree).render

    def tree
      @task_list_monitor.synchronize do
        calculate_deps unless @pend_list

        task_list.select { |task_item| task_item.score.zero? }.to_h do |task_item|
          key = [task_item.state, task_item.name].join(' ')
          [key, sub_tree(task)]
        end
      end
    end

    def sub_tree(task)
      task.depends.map do |subtask_name|
        task_item = @task_map[subtask_name]
        key = [task_item.state, task_item.name].join(' ')

        { key => sub_tree(task_item) }
      end
    end

    def start
      state_exec!
      @report_task_queue ||= Queue.new
      run_loop
    end

    def run_loop
      log_ini self, '** STARTING **'
      @keep_run_loop = true
      StdThreadProxy.install

      loop do
        loop_distribute_tasks_to_workers

        break unless @keep_run_loop

        loop_receive_reported_tasks_from_workers
      end
    ensure
      StdThreadProxy.uninstall
      worker_cleanup
      state_done!
      log_fin self, '** STOPPED **'
    end

    def loop_distribute_tasks_to_workers
      tasks_by_worker_class_map = @task_list_monitor.synchronize do
        stats = %w[task_list pend_list exec_list done_list fail_list].map do |list|
          { list => instance_variable_get("@#{list}")&.count }
        end
        log_info "RUN_LOOP stats #{stats.to_yaml}"

        pend_list.group_by(&:worker_class)
      end

      return (@keep_run_loop = false) if pend_list.empty? && exec_list.empty?

      log_info tasks_by_worker_class_map.transform_values(&:count).as_json.to_yaml

      tasks_by_worker_class_map.each do |worker_class, tasks|
        worker_instance(worker_class).receive_tasks tasks
      end
    end

    def loop_receive_reported_tasks_from_workers
      reported_tasks = []
      reported_tasks << @report_task_queue.pop

      reported_tasks << @report_task_queue.pop while @report_task_queue.length.positive?

      @task_list_monitor.synchronize do
        reported_tasks.each do |task|
          process_reported_task task
        end
      end
    end

    def process_reported_task(task)
      @exec_list.delete task

      if task.done?
        @done_list.push task
        task.dependants.each do |dependant_task_name|
          dependant_task = @task_map[dependant_task_name]
          dependant_task.depends.delete task.name
          next unless dependant_task.depends.count.zero?

          dependant_task.state_pend!
          @deps_list.delete dependant_task
          @pend_list.push dependant_task
        end
      elsif task.fail?
        @fail_list.push task
      end
    end

    def take_task(task)
      @task_list_monitor.synchronize do
        task.state_exec!
        pend_list.delete task
        exec_list.push task
      end
    end

    def worker_instance(worker_class)
      @worker_instance_map[worker_class] ||= worker_class.new(runner: self)
    end

    def worker_cleanup
      @worker_instance_map.each_value(&:finalize)
      @worker_instance_map = {}
    end

    def report_task(task) = @report_task_queue.push task
  end
end
