# Fasten your seatbelts!

FIXME: Add intro here

## Roadmap

- [✔︎] define task to be run to reach a goal, with dependencies (similar to rake, make, and others)
- [✔︎] run task in parallel by default
- [ ] dynamicly change the number of worker processes
- [✔︎] allow to programatically define new tasks
- [ ] allow to programatically redefine existing tasks
- [ ] keep each task log in a separate file, to easily debug errors
- [ ] early stop in case of a failure
- [✔︎] for non-tty execution, report with a simple progress log in STDOUT
- [ ] calculate ETA of script, based on previos executions of the same script
- [ ] for tty execution: start in background and provide a curses interface. When quit, the background process will keep running
- [ ] provide a cli for running simple tasks
- [ ] the cli can control (pause/stop/resume) other running executions


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'fasten'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install fasten

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/fasten. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Fasten project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/fasten/blob/master/CODE_OF_CONDUCT.md).
