module Fasten
  module LoadSave
    def load(path)
      items = YAML.safe_load(File.read(path)).each do |name, params|
        params.each do |key, val|
          next unless val.is_a?(String) && (match = %r{^/(.+)/$}.match(val))

          params[key] = Regexp.new(match[1])
        end

        add Fasten::Task.new({ name: name }.merge(params))
      end

      log_info "Loaded #{items.count} tasks from #{path}"
    end

    def save(path)
      keys = %i[after shell stats]

      items = task_list.map do |task|
        data = task.to_h.select do |key, _val|
          keys.include? key
        end

        [task.name, data]
      end.to_h

      File.write path, items.to_yaml

      log_info "Loaded #{items.count} tasks into #{path}"
    end
  end
end
