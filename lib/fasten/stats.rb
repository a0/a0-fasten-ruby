module Fasten
  module Stats
    attr_accessor :stats_data, :stats_entries

    def initialize_stats
      return unless stats

      @stats_path = "#{ENV['HOME']}/.fasten/stats/#{name}.csv" if ENV['HOME']
      FileUtils.mkdir_p File.dirname(@stats_path)
    rescue StandardError
      @stats_path = nil
    end

    def stats_create_entry(state, target)
      {
        'state' => state.to_s,
        'kind'  => target.is_a?(Fasten::Executor) ? 'executor' : 'task',
        'name'  => target.name,
        'ini'   => target.ini.to_f,
        'fin'   => target.fin.to_f,
        'run'   => target.fin - target.ini
      }
    end

    def stats_add_entry(state, target)
      return unless target.ini && target.fin

      entry = stats_create_entry(state, target)
      self.stats_data ||= []
      self.stats_entries ||= []
      stats_data << entry
      stats_entries << entry

      history = stats_history(entry)

      update_cnt(history, entry)
      update_avg(history, entry)
      update_std(history, entry)
    end

    FLOAT_FORMATTER = ->(f) { format('%7.3f', f) }

    def stats_table_run
      sub = stats_entries.select { |x| x['kind'] == 'task' }.map { |x| x['run'] }.sum
      tot = stats_entries.select { |x| x['kind'] == 'executor' }.map { |x| x['run'] }.sum

      [sub, tot]
    end

    def split_time(time)
      sign = time.negative? ? '-' : ''
      time = -time if time.negative?

      hours, seconds = time.divmod(3600)
      minutes, seconds = seconds.divmod(60)
      seconds, decimal = seconds.divmod(1)
      milliseconds, _ignored = (decimal.round(4) * 1000).divmod(1)

      [sign, hours, minutes, seconds, milliseconds]
    end

    def hformat(time, total = nil)
      sign, hours, minutes, seconds, milliseconds = split_time time

      str = hours.zero? ? format('%.1s%02d:%02d.%03d', sign, minutes, seconds, milliseconds) : format('%.1s%02d:%02d:%02d.%03d', sign, hours, minutes, seconds, milliseconds)
      str += format(' (%.1f%%)', 100.0 * time / total) if total

      str
    end

    def stats_table
      sub, tot = stats_table_run

      Hirb::Console.render_output(stats_entries,
                                  fields: %w[state kind name run cnt avg std], unicode: true, class: 'Hirb::Helpers::AutoTable',
                                  filters: { 'run' => FLOAT_FORMATTER, 'avg' => FLOAT_FORMATTER, 'std' => FLOAT_FORMATTER },
                                  description: false)

      puts format('∑tasks: %<task>s ∑executed: %<executed>s saved: %<saved>s workers: %<workers>s',
                  task: hformat(sub), executed: hformat(tot, sub), saved: hformat(sub - tot, sub), workers: workers.to_s)
    end

    def stats_history(entry)
      stats_data.select { |e| e['state'] == entry['state'] && e['kind'] == entry['kind'] && e['name'] == entry['name'] }
    end

    def update_cnt(history, entry)
      entry['cnt'] = history.size
    end

    def update_avg(history, entry)
      entry['avg'] = history.inject(0.0) { |s, x| s + x['run'].to_f } / history.size
    end

    def update_std(history, entry)
      entry['std'] = Math.sqrt(history.inject(0.0) { |v, x| v + (x['run'].to_f - entry['avg'])**2 })
    end
  end
end
