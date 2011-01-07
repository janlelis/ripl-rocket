require 'ripl'
require 'unicode/display_width'

module Ripl
  module Rocket
    VERSION = '0.1.0'

    TPUT = {
      :sc   => `tput sc`,
      :rc   => `tput rc`,
      :cuu1 => `tput cuu1`,
      :cuf1 => `tput cuf1`,
    }

    COLORS = {
      :nothing      => '0;0',
      :black        => '0;30',
      :red          => '0;31',
      :green        => '0;32',
      :brown        => '0;33',
      :blue         => '0;34',
      :purple       => '0;35',
      :cyan         => '0;36',
      :light_gray   => '0;37',
      :dark_gray    => '1;30',
      :light_red    => '1;31',
      :light_green  => '1;32',
      :yellow       => '1;33',
      :light_blue   => '1;34',
      :light_purple => '1;35',
      :light_cyan   => '1;36',
      :white        => '1;37',
    }

    class << self
      def reset_output_height
        @height_counter = []
      end

      def get_height(data)
        lines      = data.to_s.count("\n")
        long_lines = data.to_s.split("\n").inject(0){ |sum, line|
          sum + (line.display_size / `tput cols`.to_i)
        }
        lines + long_lines
      end

      def track_output_height(data)
        @height_counter ||= []
        @height_counter << get_height(data)
      end

      def output_height
        1 + ( @height_counter == [0] ? 0 : @height_counter.reduce(:+) || 0 )
      end
    end

    module Shell
      def loop_eval(input)
        Ripl::Rocket.reset_output_height
        super
      end

      def print_result(result)
        return if @error_raised
        if config[:rocket_mode]
          # get important data
          screen_length = `tput cols`.to_i
          screen_height = `tput lines`.to_i
          last_line_without_prompt = @input.split("\n").last || ''
          offset = (last_line_without_prompt.display_size + prompt.display_size ) % screen_length.to_i
          output_length = result.inspect.display_size
          rocket_length = config[:rocket_prompt].display_size
          stdout_height  = Ripl::Rocket.output_height
          color_config = config[:rocket_color]
          color_code   = !color_config || color_config.to_s[/^[\d;]+$/] ?
            color_config : Ripl::Rocket::COLORS[color_config.to_sym]
          colored_rocket = color_code ? "\e[#{ color_code }m#{ config[:rocket_prompt] }\e[0;0m"
                                      : config[:rocket_prompt]

          # auto rocket mode:  only display rocket if line has enough space left
          line_too_long   = screen_length <= offset + rocket_length + output_length
          height_too_long = stdout_height >= screen_height
          if !(config[:rocket_mode] == :auto && ( line_too_long || height_too_long ) )
            if !height_too_long
              print TPUT[:sc] +                   # save cursor position
                    TPUT[:cuu1]*stdout_height +   # move cursor upwards    to the original input line
                    TPUT[:cuf1]*offset +          # move cursor rightwards to the original input offset
                    colored_rocket +              # draw rocket prompt
                    format_result(result).sub( /^#{result_prompt}/, '' ) +         # draw result (without prompt)
                    TPUT[:rc] +                   # restore cursor position
                    ( config[:rocket_mode] != :auto && line_too_long  ? "\n" : '') # add a line for always-rocket mode

            else # too much stdout, but in "always rocket mode"
              puts colored_rocket +              # draw rocket prompt
                   format_result(result).sub( /^#{result_prompt}/, '' )            # draw result (without prompt)
            end
            return
          end
        end
        # else: no rocket ;)
        super
      end
    end

    # load stream extensions
    require File.dirname(__FILE__) + "/rocket/stream_ext"
  end
end

Ripl::Shell.include Ripl::Rocket::Shell

Ripl.config[:rocket_mode]     = :auto  if Ripl.config[:rocket_mode].nil?
Ripl.config[:rocket_prompt] ||= " #=> "
Ripl.config[:rocket_color]  ||= :blue

# J-_-L
