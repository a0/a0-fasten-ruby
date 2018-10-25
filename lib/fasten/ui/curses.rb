# frozen_string_literal: true

require 'forwardable'

module Fasten
  module UI
    class Curses
      include ::Curses
      extend Forwardable
      def_delegators :executor, :worker_list, :task_list, :task_done_list, :task_error_list, :task_running_list, :task_waiting_list, :worker_list
      def_delegators :executor, :name, :workers, :workers=, :state, :state=

      attr_accessor :n_rows, :n_cols, :clear_needed, :message, :executor

      SPINNER_STR = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
      SPINNER_LEN = SPINNER_STR.length
      PROGRESSBAR_STR = ' ▏▎▍▌▋▊▉'
      PROGRESSBAR_LEN = PROGRESSBAR_STR.length

      def initialize(executor:)
        @executor = executor
      end

      def update
        setup unless @setup_done
        ui_keyboard
        clear if clear_needed
        draw_title
        ui_workers
        ui_tasks

        refresh
        self.clear_needed = false
      end

      def draw_title
        ui_text_aligned(0, :left, 'Fasten your seatbelts!')
        ui_text_aligned(0, :center, name.to_s)
        ui_text_aligned(0, :right, Time.new.to_s)
      end

      def cleanup
        close_screen
        @setup_done = nil
      end

      def setup
        init_screen
        self.n_rows = lines
        self.n_cols = cols
        stdscr.keypad = true
        stdscr.nodelay = true
        setup_color
        noecho
        cbreak
        nonl
        curs_set 0
        @setup_done = true
      end

      def setup_color
        start_color
        use_default_colors

        init_pair 1, Curses::COLOR_YELLOW, -1
        init_pair 2, Curses::COLOR_GREEN, -1
        init_pair 3, Curses::COLOR_RED, -1
        init_pair 4, Curses::COLOR_WHITE, -1
      end

      def ui_text_aligned(row, align, str, attrs = nil)
        if align == :center
          setpos row, (n_cols - str.length) / 2
        elsif align == :right
          setpos row, n_cols - str.length
        else
          setpos row, 0
        end

        attrset attrs if attrs
        addstr str
        attroff attrs if attrs

        str.length
      end

      def force_clear
        self.clear_needed = true
      end

      def ui_keyboard
        return unless (key = stdscr.getch)

        self.message = nil

        if key == Curses::Key::LEFT
          if workers <= 1
            self.message = "Can't remove 1 worker left, press [P] to pause"
          else
            self.workers -= 1
            self.message = "Decreasing max workers to #{workers}"
          end
        elsif key == Curses::Key::RIGHT
          self.workers += 1
          self.message = "Increasing max workers to #{workers}"
        elsif key == 'q'
          self.message = 'Will quit when running tasks end'
          self.state = :QUITTING
        elsif key == 'p'
          self.message = 'Will pause when running tasks end'
          self.state = :PAUSING
        elsif key == 'r'
          self.state = :RUNNING
        end

        force_clear
      end

      def ui_workers_summary
        running_count = task_running_list.count
        waiting_count = task_waiting_list.count
        workers_count = worker_list.count

        "Procs: #{running_count} run #{workers_count - running_count} idle #{workers} max #{waiting_count} wait"
      end

      def ui_workers
        l = ui_text_aligned(1, :left, ui_workers_summary) + 1

        worker_list.each_with_index do |worker, index|
          setpos 1, l + index
          attrs = worker.running? ? A_STANDOUT : color_pair(4) | A_DIM
          attrset attrs
          addstr worker.running? ? 'R' : '_'
          attroff attrs
        end

        ui_state
      end

      def ui_state
        if state == :RUNNING
          attrs = color_pair(2)
        elsif state == :PAUSING
          attrs = color_pair(1) | A_BLINK | A_STANDOUT
        elsif state == :PAUSED
          attrs = color_pair(1) | A_STANDOUT
        elsif state == :QUITTING
          attrs = color_pair(3) | A_BLINK | A_STANDOUT
        end

        l = ui_text_aligned(1, :right, state.to_s, attrs)
        return unless message

        setpos 1, n_cols - l - message.length - 1
        addstr message
      end

      def ui_progressbar(row, col_ini, col_fin, count, total)
        slice = total.to_f / (col_fin - col_ini + 1)
        col_ini.upto col_fin do |col|
          setpos row, col
          count -= slice
          if count.positive?
            addstr PROGRESSBAR_STR[-1]
          elsif count > -slice
            addstr PROGRESSBAR_STR[(count * PROGRESSBAR_LEN / slice) % PROGRESSBAR_LEN]
          else
            addstr '.'
          end
        end
      end

      def ui_task_icon(task)
        case task.state
        when :RUNNING
          SPINNER_STR[task.worker&.spinner]
        when :FAIL
          '✘'
        when :DONE
          '✔'
        else
          '…'
        end
      end

      def ui_task_color(task)
        case task.state
        when :RUNNING
          color_pair(1) | A_TOP
        when :FAIL
          color_pair(3) | A_TOP
        when :DONE
          color_pair(2) | A_TOP
        else
          color_pair(4) | A_TOP
        end
      end

      def ui_task_string(task, y, x, icon: nil, str: nil)
        setpos y, x

        attrs = ui_task_color(task)
        icon = ui_task_icon(task) if icon

        str ||= icon ? "#{icon} #{task}" : task.to_s

        attrset attrs if attrs
        addstr str
        attroff attrs if attrs

        x + str.length
      end

      def ui_tasks
        worker_list.each do |worker|
          worker.spinner = (worker.spinner + 1) % SPINNER_LEN if worker.running?
        end

        count_done = task_done_list.count
        count_total = task_list.count
        tl = count_total.to_s.length
        col_ini = ui_text_aligned(2, :left, format("Tasks: %#{tl}d/%d", count_done, count_total)) + 1
        col_fin = n_cols - 5
        ui_text_aligned(2, :right, "#{(count_done * 100 / count_total).to_i}%") if count_total.positive?

        ui_progressbar(2, col_ini, col_fin, count_done, count_total)

        max = 2
        list = task_list.sort_by(&:run_score)
        list.each_with_index do |task, index|
          next if 3 + index >= n_rows

          x = ui_task_string(task, 3 + index, 2, icon: true)
          max = x if x > max
        end

        list.each_with_index do |task, index|
          next if 3 + index >= n_rows

          if task.dif
            setpos 3 + index, max + 2
            ui_task_string(task, 3 + index, max + 2, str: format('%.2f s', task.dif))
          elsif task.depends && !task.depends.empty?
            setpos 3 + index, max
            x = max + 2
            addstr ':'
            task.depends.each do |dependant_task|
              x = ui_task_string(dependant_task, 3 + index, x) + 1
            end
          end
        end
      end
    end
  end
end
