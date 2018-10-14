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
      clear
      ui_title
      ui_workers
      ui_tasks

      refresh
    end

    def ui_workers_summary
      "Procs: #{task_running_list.count} run #{worker_list.count - task_running_list.count} idle #{workers} max"
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

    def ui_task_string(task, y, x, icon: nil)
      setpos y, x

      case task.state
      when :RUNNING
        attrs = color_pair(1) | A_TOP
        icon = SPINNER_STR[task.worker&.spinner] if icon
      when :ERROR
        attrs = color_pair(3)
        icon = '✘︎' if icon
      when :DONE
        attrs = color_pair(2)
        icon = '✔︎' if icon
      else
        attrs = color_pair(4) | A_DIM
        icon = '…' if icon
      end

      str = icon ? "#{icon} #{task}" : task.to_s

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
      col_ini = ui_text_aligned(2, :left, format("Tasks: %#{tl}d/%s", count_done, count_total)) + 1
      col_fin = ui_cols - 5
      ui_text_aligned(2, :right, "#{(count_done * 100/count_total).to_i}%") if count_total.positive?

      ui_progressbar(2, col_ini, col_fin, count_done, count_total)

      max = 2
      task_list.each_with_index do |task, index|
        next if 3 + index >= ui_rows

        x = ui_task_string(task, 3 + index, 2, icon: true)
        max = x if x > max
      end

      task_list.each_with_index do |task, index|
        next if 3 + index >= ui_rows || task.depends.nil? || task.depends.empty?

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
