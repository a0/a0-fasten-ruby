RSpec.shared_examples 'basic funcionality' do |use_threads|
  process_model = use_threads ? 'threads' : 'processes'

  it "using #{process_model}, has a version number" do
    expect(Fasten::VERSION).not_to be nil
  end

  it "using #{process_model}, performs an empty runner" do |ex|
    f = Fasten::Runner.new name: ex.description, use_threads: use_threads
    f.perform
  end

  it "using #{process_model}, performs 500 tasks with 100 workers, without dependencies" do |ex|
    FileUtils.rm_rf Dir.glob('*.testfile')
    f = Fasten::Runner.new name: ex.description, workers: 100, use_threads: use_threads
    500.times do |index|
      f.add Fasten::Task.new(name: index.to_s, shell: "sleep 0.2; touch #{index}.testfile")
    end
    f.perform

    files = Dir['*.testfile']
    items = f.task_list.map { |item| "#{item}.testfile" }
    FileUtils.rm_rf Dir.glob('*.testfile')

    expect(files.sort).to eq(items.sort)
  end

  it "using #{process_model}, performs 500 tasks with 5 workers, including dependencies" do |ex|
    FileUtils.rm_rf Dir.glob('*.testfile')
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

    f = Fasten::Runner.new name: ex.description, workers: 50, use_threads: use_threads
    l.values.map(&:values).flatten.each do |item|
      f.add Fasten::Task.new(name: item[:task], after: item[:after], shell: item[:shell])
    end
    f.perform

    files = Dir['*.testfile']
    items = f.task_list.map { |item| "#{item}.testfile" }
    FileUtils.rm_rf Dir.glob('*.testfile')

    expect(files.sort).to eq(items.sort)
  end
end

RSpec.describe Fasten do
  it_behaves_like 'basic funcionality', false if OS.posix?
  it_behaves_like 'basic funcionality', true
end
