module Fasten
  module LoadSave
    attr_reader :stats_path

    def load(path)
      items = YAML.safe_load(File.read(path)).each do |name, params|
        if params.is_a? String
          params = { after: params }
        else
          params&.each do |key, val|
            next unless val.is_a?(String) && (match = %r{^/(.+)/$}.match(val))

            params[key] = Regexp.new(match[1])
          end
        end

        add Fasten::Task.new({ name: name }.merge(params || {}))
      end

      log_info "Loaded #{items.count} tasks from #{path}"
    end

    def save(path)
      keys = %i[after shell]

      items = task_list.map do |task|
        data = task.to_h.select do |key, _val|
          keys.include? key
        end

        [task.name, data]
      end.to_h

      File.write path, items.to_yaml

      log_info "Loaded #{items.count} tasks into #{path}"
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

      CSV.open(@stats_path, 'wb') do |csv|
        csv << stats_data.first.keys

        stats_data.each do |data|
          csv << data.values
        end
      end
    end

    def setup_stats(name)
      @stats_path = "#{ENV['HOME']}/.fasten/stats/#{name}.csv" if ENV['HOME'] && name
      FileUtils.mkdir_p File.dirname(@stats_path)
    rescue StandardError
      @stats_path = nil
    end
  end
end
