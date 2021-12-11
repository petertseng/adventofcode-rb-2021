def step(octopi, width)
  flashed = 0
  to_flash = []

  new_octopi = octopi.map.with_index { |c, i|
    if c == 9
      to_flash << i
      0
    else
      c + 1
    end
  }

  to_flash.each { |fpos|
    flashed += 1
    fx = fpos % width
    [-width, 0, width].each { |dy|
      next if fpos + dy < 0
      [-1, 0, 1].each { |dx|
        next if dy + dx == 0
        next unless (0...width).cover?(fx + dx)
        npos = fpos + dy + dx

        next unless (c = new_octopi[npos])

        if c == 9
          # in Ruby, appending while iterating will result in new item being iterated.
          # and this is what we want here
          to_flash << npos
          new_octopi[npos] = 0
        elsif c != 0
          new_octopi[npos] = c + 1
        end
      }
    }
  }

  [new_octopi, flashed]
end

print_t = []
ARGV.each { |arg|
  next unless arg.start_with?('-t')
  print_t.concat(arg[2..-1].split(?,).map(&method(:Integer)))
}
print_t.sort!

octopi = ARGF.map { |line|
  line.chomp.each_char.map(&method(:Integer)).freeze
}
height = octopi.size
width = octopi[0].size
raise "inconsistent width #{octopi.map(&:size)}" if octopi.any? { |row| row.size != width }
size = height * width
octopi.flatten!
octopi.freeze

total_flashes = 0

1.step { |t|
  octopi, flashes = step(octopi, width)

  if print_t[0] == t
    octopi.each_slice(width) { |row| puts row.map { |x| x == 0 ? "\e[1m0\e[0m" : x }.join }
    print_t.shift
  end

  total_flashes += flashes
  puts total_flashes if t == 100
  break puts t if flashes == size
}
