require 'English'
require 'fileutils'

Fasten.register do # rubocop:disable Metrics/BlockLength
  task 'clean' do
    puts "#{$PID} running clean…"
    sleep 0.5
    FileUtils.touch 'clean.testfile'
    puts "#{$PID} ok clean."
  end

  task 'env-setup' do
    puts "#{$PID} running env-setup…"
    sleep 1
    FileUtils.touch 'env-setup.testfile'
    puts "#{$PID} ok env-setup."
  end

  task 'db-setup-1', after: %w[db-update compile-1] do
    puts "#{$PID} running db-setup-1…"
    sleep 1.5
    FileUtils.touch 'db-setup-1.testfile'
    puts "#{$PID} ok db-setup-1."
  end

  task 'db-setup-2', after: 'db-update' do
    puts "#{$PID} running db-setup-2…"
    sleep 2
    FileUtils.touch 'db-setup-2.testfile'
    puts "#{$PID} ok db-setup-2."
  end

  task 'db-update', after: %w[db-sync db-reset] do
    puts "#{$PID} running db-update…"
    sleep 2.5
    FileUtils.touch 'db-update.testfile'
    puts "#{$PID} ok db-update."
  end

  task 'db-reset', after: 'env-setup' do
    puts "#{$PID} running db-reset…"
    sleep 3
    FileUtils.touch 'db-reset.testfile'
    puts "#{$PID} ok db-reset."
  end

  task 'db-sync', after: 'env-setup' do
    puts "#{$PID} running db-sync…"
    sleep 3.5
    FileUtils.touch 'db-sync.testfile'
    puts "#{$PID} ok db-sync."
  end

  task 'fs-sync-1', after: 'env-setup' do
    puts "#{$PID} running fs-sync-1…"
    sleep 4
    FileUtils.touch 'fs-sync-1.testfile'
    puts "#{$PID} ok fs-sync-1."
  end

  task 'fs-sync-2', after: 'env-setup' do
    puts "#{$PID} running fs-sync-2…"
    sleep 4.5
    FileUtils.touch 'fs-sync-2.testfile'
    puts "#{$PID} ok fs-sync-2."
  end

  task 'compile-1', after: 'env-setup' do
    puts "#{$PID} running compile-1…"
    sleep 5
    FileUtils.touch 'compile-1.testfile'
    puts "#{$PID} ok compile-1."
  end

  task 'compile-2', after: 'env-setup' do
    puts "#{$PID} running compile-2…"
    sleep 5.5
    FileUtils.touch 'compile-2.testfile'
    puts "#{$PID} ok compile-2."
  end

  task 'compile-3', after: 'env-setup' do
    puts "#{$PID} running compile-3…"
    sleep 6
    FileUtils.touch 'compile-3.testfile'
    puts "#{$PID} ok compile-3."
  end

  task 'version', after: 'env-setup' do
    puts "#{$PID} running version…"
    sleep 6.5
    FileUtils.touch 'version.testfile'
    puts "#{$PID} ok version."
  end
end
