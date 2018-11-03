require 'bundler/setup'
require 'fasten'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

class ErrorWorker < Fasten::Worker
  def initialize(*)
    super
    @fail_at ||= ENV['FAILT_AT'] || 10
  end

  def perform(task)
    @count = (@count || 0) + 1
    raise "Simulating Error, counter: #{@count}" if (@count % @fail_at).zero?

    super
  end
end
