require_relative 'lib/search'

print_map = ARGV.delete('-m')
verbose2 = ARGV.delete('-vv')
verbose = verbose2 || ARGV.delete('-v')

heights = ARGF.map { |line|
  line.chomp.each_char.map(&method(:Integer)).freeze
}.freeze
height = heights.size
width = heights[0].size
raise "inconsistent width #{heights.map(&:size)}" if heights.any? { |row| row.size != width }

lows = []

risk = heights.each_with_index.sum { |row, y|
  row.each_with_index.sum { |val, x|
    val = heights[y][x]
    next 0 if y > 0 && val >= heights[y - 1][x]
    next 0 if x > 0 && val >= row[x - 1]
    next 0 if x < row.size - 1 && val >= row[x + 1]
    next 0 if y < heights.size - 1 && val >= heights[y + 1][x]
    lows << y * width + x
    val + 1
  }
}

lows.freeze

puts "#{"#{lows.size} + #{lows.sum { |pos| heights.dig(*pos.divmod(width)) }} = " if verbose}#{risk}"

def basin(heights, height, width, pos)
  neigh = ->pos {
    y, x = pos.divmod(width)
    ns = []
    ns << pos - width if y > 0 && heights[y - 1][x] != 9
    ns << pos - 1 if x > 0 && heights[y][x - 1] != 9
    ns << pos + 1 if x < width - 1 && heights[y][x + 1] != 9
    ns << pos + width if y < height - 1 && heights[y + 1][x] != 9
    ns
  }
  Search.bfs(pos, num_goals: width * height, neighbours: neigh, goal: ->_ { true })[:goals]
end

basins = lows.map { |pos| basin(heights, height, width, pos).size }
top = basins.max(3)
puts "#{"#{top.join(' * ')} = " if verbose}#{top.max(3).reduce(:*)}"

if verbose2
  puts "#{lows.size} lows:"
  lows.zip(basins).sort_by(&:last).each { |pos, basin|
    pos2 = pos.divmod(width)
    puts "pos #{pos2} height #{heights.dig(*pos2)} basin #{basin}"
  }
end

if print_map
  require 'set'
  # I'll just show all tied ones, it's fine
  thresh = basins.max(3)[-1]
  max_basin = Set.new
  lows.zip(basins).each { |pos, basin|
    next if basin < thresh
    max_basin |= basin(heights, height, width, pos).keys
  }

  heights.each_with_index { |row, y|
    row.each_with_index { |val, x|
      pos = y * width + x
      c = val == 9 ? 31 : lows.include?(pos) ? 34 : max_basin.include?(pos) ? 32 : 33
      print "\e[1;#{c}m#{val}"
    }
    puts "\e[0m"
  } if print_map
end

# export for bench
@lows = lows
@heights = heights
