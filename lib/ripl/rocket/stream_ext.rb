# hook into streams to count lines used in stdout
class << $stdout
  alias write_without_rocket write
  def write(data)
    Ripl::Rocket.track_output_height data
    write_without_rocket data
  end
end

class << $stderr
  alias write_without_rocket write
  def write(data)
    Ripl::Rocket.track_output_height data
    write_without_rocket data
  end
end

# J-_-L
