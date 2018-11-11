require 'fasten/ui/console'

module Fasten
  module Support
    module UI
      def ui
        require 'fasten/ui/curses'

        @ui ||= if ui_mode.to_s == 'curses' && STDIN.tty? && STDOUT.tty?
                  Fasten::UI::Curses.new(runner: self)
                else
                  Fasten::UI::Console.new(runner: self)
                end
      rescue StandardError, LoadError
        @ui ||= Fasten::UI::Console.new(runner: self)
      end

      def run_ui
        ui.update

        yield
      ensure
        ui.cleanup
      end
    end
  end
end
