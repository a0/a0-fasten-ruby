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

    def stats_add_entry(object, state, target)
      return unless target.ini && target.fin

      entry = stats_create_entry(state, target)
      object.stats_data ||= []
      object.stats_data << entry

      history = stats_history(object, entry)

      update_avg(history, entry)
      update_std(history, entry)
    end

    def stats_history(object, entry)
      object.stats_data.select { |e| e['state'] == entry['state'] && e['kind'] == entry['kind'] && e['name'] == entry['name'] }
    end

    def update_avg(history, entry)
      entry['avg'] = history.inject(0.0) { |s, x| s + x['run'].to_f } / history.size
    end

    def update_std(history, entry)
      entry['std'] = Math.sqrt(history.inject(0.0) { |v, x| v + (x['run'].to_f - entry['avg'])**2 })
    end
  end
end
