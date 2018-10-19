module Fasten
  module Stats
    def stats_create_entry(state, target)
      {
        'state' => state.to_s,
        'kind' => target.is_a?(Fasten::Executor) ? 'executor' : 'task',
        'name' => target.name,
        'ini' => target.ini.to_f,
        'fin' => target.fin.to_f,
        'run' => target.fin - target.ini
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

      update_avg(history, entry)
      update_std(history, entry)
    end

    FLOAT_FORMATTER = ->(f) { format('%7.3f', f) }

    def stats_table_run
      sub = stats_entries.select { |x| x['kind'] == 'task' }.map { |x| x['run'] }.sum
      tot = stats_entries.select { |x| x['kind'] == 'executor' }.map { |x| x['run'] }.sum

      [sub, tot]
    end

    def stats_table
      sub, tot = stats_table_run

      Hirb::Console.render_output(stats_entries,
                                  fields: %w[state kind name run avg std], unicode: true, class: 'Hirb::Helpers::AutoTable',
                                  filters: { 'run' => FLOAT_FORMATTER, 'avg' => FLOAT_FORMATTER, 'std' => FLOAT_FORMATTER },
                                  description: false)

      puts format('Tasks total: %.3f s. Executed in: %.3f s. Saved: %.3f s. (%.1f)%% %.0f workers', sub, tot, sub - tot, 100 * (sub - tot) / sub, workers)
    end

    def stats_history(entry)
      stats_data.select { |e| e['state'] == entry['state'] && e['kind'] == entry['kind'] && e['name'] == entry['name'] }
    end

    def update_avg(history, entry)
      entry['avg'] = history.inject(0.0) { |s, x| s + x['run'].to_f } / history.size
    end

    def update_std(history, entry)
      entry['std'] = Math.sqrt(history.inject(0.0) { |v, x| v + (x['run'].to_f - entry['avg'])**2 })
    end
  end
end
