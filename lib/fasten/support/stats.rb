require 'csv'
require 'hirb'
require 'fileutils'

module Fasten
  module Support
    module Stats
      attr_writer :stats_data, :stats_entries
      attr_reader :stats_path

      def initialize_stats
        return unless stats

        @stats_path = "#{ENV['HOME']}/.fasten/stats/#{name}.csv" if ENV['HOME']
        FileUtils.mkdir_p File.dirname(@stats_path)
      rescue StandardError
        @stats_path = nil
      end

      def load_stats
        return unless @stats_path && File.exist?(@stats_path)

        self.stats_data = []
        CSV.foreach(@stats_path, headers: true) do |row|
          stats_data << row.to_h
        end

        @task_waiting_list = nil
      rescue StandardError
        nil
      ensure
        self.stats ||= {}
      end

      def save_stats
        return unless @stats_path && stats_data

        keys = %w[state kind name run cnt avg std err]

        CSV.open(@stats_path, 'wb') do |csv|
          csv << keys

          stats_data.each do |data|
            csv << keys.map { |i| data[i] }
          end
        end
      end

      def stats_create_entry(state, target)
        { 'state' => state.to_s,
          'kind'  => target.kind,
          'name'  => target.name,
          'ini'   => target.ini.to_f,
          'fin'   => target.fin.to_f,
          'run'   => target.fin - target.ini,
          'worker' => target.respond_to?(:worker) ? target.worker.name : nil }
      end

      def stats_data
        @stats_data ||= []
      end

      def stats_entries
        @stats_entries ||= []
      end

      def stats_add_entry(state, target)
        return unless target.ini && target.fin

        entry = stats_create_entry(state, target)
        stats_data << entry
        stats_entries << entry

        history = stats_history(entry)

        update_stats(history, entry)
      end

      FLOAT_FORMATTER = ->(f) { format('%7.3f', f) }

      def stats_table_run
        sub = stats_entries.select { |x| x['kind'] == 'task' }.map { |x| x['run'] }.sum
        tot = stats_entries.select { |x| x['kind'] == 'runner' }.map { |x| x['run'] }.sum

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
        sign, hours, mins, secs, msecs = split_time time

        str = hours.zero? ? format('%.1s%02d:%02d.%03d', sign, mins, secs, msecs) : format('%.1s%02d:%02d:%02d.%03d', sign, hours, mins, secs, msecs)
        str += format(' (%.1f%%)', 100.0 * time / total) if total

        str
      end

      def stats_table
        sub, tot = stats_table_run

        Hirb::Console.render_output(stats_entries,
                                    fields: %w[state kind name run cnt avg std err worker], unicode: true, class: 'Hirb::Helpers::AutoTable',
                                    filters: { 'run' => FLOAT_FORMATTER, 'avg' => FLOAT_FORMATTER, 'std' => FLOAT_FORMATTER, 'err' => FLOAT_FORMATTER },
                                    description: false)

        puts format('∑tasks: %<task>s runner: %<runner>s saved: %<saved>s workers: %<workers>s',
                    task: hformat(sub), runner: hformat(tot, sub), saved: hformat(sub - tot, sub), workers: workers.to_s)
      end

      def stats_history(entry)
        stats_data.select { |e| e['state'] == entry['state'] && e['kind'] == entry['kind'] && e['name'] == entry['name'] }.map { |x| x['run'].to_f }
      end

      def stats_last(item)
        return item.last if item.last

        item.last = stats_data.select { |e| e['kind'] == item.kind && e['name'] == item.name }.last || {}
      end

      def update_stats(history, entry)
        entry['cnt'] = count = history.size
        entry['avg'] = avg = history.sum.to_f / count
        entry['std'] = std = Math.sqrt(history.inject(0.0) { |v, x| v + (x - avg)**2 })
        entry['err'] = std / Math.sqrt(count) if count.positive?
      end
    end
  end
end
