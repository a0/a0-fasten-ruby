# Fasten

Enjoy running ruby code and other tasks, in parallel.

This is a major rewrite, primarly focusing in our current needs:
  - ruby >= 3.2
  - macOS and Linux
  - better error reporting/handling

## Feature Roadmap

### General
- [ ] Ruby >= 3.2.
- [ ] macOS support.
- [ ] Linux support.
- [ ] Only one model will be supported. Currently: ThreadPool.
- [ ] Message passing based implementation, for sending/receiving job data.

### Task definitions
- [ ] API for creating runners.
- [ ] Block based code definition.
- [ ] Custom worker class: custom/dynamic number of workers, code definition, tasks , error handling.
- [ ] Run shell code using `tty-command`.

### Execution
- [ ] Tasks are executed in parallel, using thread pools.
- [ ] Block based code uses a default worker class, which uses the number of cores as the number of workers.
- [ ] In case of errors, it can be defined to run everything left or stop the whole process.
- [ ] Keep the last N running stats by worker class.
- [ ] Calculate ETA based in saved stats.
- [ ] Every task output is redirected to a log file in .fasten/log/«worker»-«task name».log
- [ ] A (graph) report is generated for all registered tasks.


## Installation


Install the gem and add to the application's Gemfile by executing:

    $ bundle add fasten

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install fasten

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Make a new relese

Just run the provided script and follow the instructions:

    $ bin/release-version

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/a0/a0-fasten-ruby. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/a0/a0-fasten-ruby/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Fasten project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/a0/a0-fasten-ruby/blob/main/CODE_OF_CONDUCT.md).
