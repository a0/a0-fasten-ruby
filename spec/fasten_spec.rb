RSpec.describe Fasten do
  it 'has a version number' do
    expect(Fasten::VERSION).not_to be nil
  end

  it 'performs an empty runner' do |ex|
    f = Fasten::Runner.new name: ex.description
    f.perform
    f.stats_table
  end

  it 'performs 500 tasks with 100 workers, without dependencies' do |ex|
    `rm -f *.testfile`
    f = Fasten::Runner.new name: ex.description, workers: 100
    500.times do |index|
      f.add Fasten::Task.new(name: index.to_s, shell: "sleep 0.2; touch #{index}.testfile")
    end
    f.perform
    f.stats_table

    files = Dir['*.testfile']
    items = f.task_list.map { |item| "#{item}.testfile" }
    `rm -f *.testfile`

    raise "Files don't match, files: #{files} items: #{items}" unless files.sort == items.sort
  end

  it 'performs 500 tasks with 5 workers, including dependencies' do |ex|
    `rm -f *.testfile`
    l = {}
    500.times do
      m = rand(65..90).chr
      n = rand(97..122).chr
      l[m] ||= {}
      l[m][n] ||= []
      key = "task-#{m}-#{n}-#{l[m][n].count + 1}"
      l[m][n] << { task: key, after: nil, shell: "sleep 0.1; touch #{key}.testfile" }
    end

    l.values.each do |value|
      depend = nil
      value.values.flatten.sort_by { |k| k[:task] }.each do |item|
        item[:after] = depend
        depend = item[:task]
      end
    end

    f = Fasten::Runner.new name: ex.description, workers: 50
    l.values.map(&:values).flatten.each do |item|
      f.add Fasten::Task.new(name: item[:task], after: item[:after], shell: item[:shell])
    end
    f.perform
    f.stats_table

    files = Dir['*.testfile']
    items = f.task_list.map { |item| "#{item}.testfile" }
    `rm -f *.testfile`

    raise "Files don't match, files: #{files} items: #{items}" unless files.sort == items.sort
  end
end
