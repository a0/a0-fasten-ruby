# frozen_string_literal: true

module Fasten
  module UI
    include Curses

    SPINNER_STR = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    SPINNER_LEN = SPINNER_STR.length
    PROGRESSBAR_STR = ' ▏▎▍▌▋▊▉'
    PROGRESSBAR_LEN = PROGRESSBAR_STR.length

    def run_ui
      ui_setup
      ui_title
      ui_workers

      yield
    ensure
      close_screen
    end

    def ui_setup
      init_screen
      self.ui_rows = lines
      self.ui_cols = cols
      stdscr.keypad = true
      stdscr.nodelay = true
      ui_setup_color
      noecho
      cbreak
      nonl
      curs_set 0
    end

    def ui_setup_color
      start_color
      use_default_colors
      init_pair 1, Curses::COLOR_YELLOW, -1
      init_pair 2, Curses::COLOR_GREEN, -1
      init_pair 3, Curses::COLOR_RED, -1
      init_pair 4, Curses::COLOR_WHITE, -1
    end

    def ui_text_aligned(row, align, str, attrs = nil)
      if align == :center
        setpos row, (ui_cols - str.length) / 2
      elsif align == :right
        setpos row, ui_cols - str.length
      else
        setpos row, 0
      end

      attrset attrs if attrs
      addstr str
      attroff attrs if attrs

      str.length
    end

    def ui_title
      ui_text_aligned(0, :left, 'Fasten your seatbelts!')
      ui_text_aligned(0, :center, name.to_s)
      ui_text_aligned(0, :right, Time.new.to_s)
    end

    def ui_update
      ui_keyboard
      clear if ui_clear_needed
      ui_title
      ui_workers
      ui_tasks

      refresh
      self.ui_clear_needed = false
    end

    def ui_keyboard
      return unless (key = stdscr.getch)

      self.ui_message = nil

      if key == 'w'
        if workers <= 1
          self.ui_message = "Can't remove 1 worker left, press [P] to pause"
        else
          self.workers -= 1
          self.ui_message = "Decreasing max workers to #{workers}"
        end
      elsif key == 'W'
        self.workers += 1
        self.ui_message = "Increasing max workers to #{workers}"
      elsif key == 'q'
        self.ui_message = 'Will quit when running tasks end'
        self.state = :QUITTING
      elsif key == 'p'
        self.ui_message = 'Will pause when running tasks end'
        self.state = :PAUSING
      elsif key == 'r'
        self.state = :RUNNING
      end

      self.ui_clear_needed = true
    end

    def ui_workers_summary
      "Procs: #{task_running_list.count} run #{worker_list.count - task_running_list.count} idle #{workers} max #{task_waiting_list.count} wait"
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
      return unless ui_message

      setpos 1, ui_cols - l - ui_message.length - 1
      addstr ui_message
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
      col_fin = ui_cols - 5
      ui_text_aligned(2, :right, "#{(count_done * 100 / count_total).to_i}%") if count_total.positive?

      ui_progressbar(2, col_ini, col_fin, count_done, count_total)

      max = 2
      list = task_list.sort_by(&:run_score)
      list.each_with_index do |task, index|
        next if 3 + index >= ui_rows

        x = ui_task_string(task, 3 + index, 2, icon: true)
        max = x if x > max
      end

      list.each_with_index do |task, index|
        next if 3 + index >= ui_rows

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
