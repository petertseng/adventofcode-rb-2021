ITERS = 50

def enhance(enhance_rule, width, read, write, active_height, active_width, prev_active_height, prev_active_width)
  active_height.each { |y|
    above_active   = prev_active_height.cover?(y - 1)
    current_active = prev_active_height.cover?(y)
    below_active   = prev_active_height.cover?(y + 1)

    above   = read[-1] * (above_active   ? 0b011 : 0b111)
    current = read[-1] * (current_active ? 0b011 : 0b111)
    below   = read[-1] * (below_active   ? 0b011 : 0b111)

    active_width.each { |x|
      right_active = prev_active_width.cover?(x + 1)

      above   = ((above   << 1) & 0b110) | read[right_active ? (y - 1) * width + x + 1 : -1] if above_active
      current = ((current << 1) & 0b110) | read[right_active ?  y      * width + x + 1 : -1] if current_active
      below   = ((below   << 1) & 0b110) | read[right_active ? (y + 1) * width + x + 1 : -1] if below_active

      write[y * width + x] = enhance_rule.fetch(above << 6 | current << 3 | below)
    }
  }

  write[-1] = enhance_rule[read[-1] * 0b111_111_111]
end

def printarr(arr, width, active_height, active_width)
  if arr[-1] != 0
    # draw some border around the space I guess...
    draw_height = (active_height.begin - 3)...(active_height.end + 3)
    draw_width = (active_width.begin - 3)...(active_width.end + 3)
  else
    draw_height = active_height
    draw_width = active_width
  end
  draw_height.each { |y|
    draw_width.each { |x|
      border = !active_height.cover?(y) || !active_width.cover?(x)
      print(border || arr[y * width + x] != 0 ? ?# : ' ')
    }
    puts
  }
end

def bit(c)
  case c
  when ?#; 1
  when ?.; 0
  else raise "bad #{c}"
  end
end

verbose = ARGV.delete('-v')

enhance_rule = ARGF.readline(chomp: true).each_char.map(&method(:bit)).freeze
raise "bad enhance_rule needs to size 512 not #{enhance_rule.size}: #{enhance_rule}" if enhance_rule.size != 512

ARGF.readline(chomp: true).tap { |s| raise "line 2 should be empty not #{s}" unless s.empty? }

grid = ARGF.map { |line|
  line.chomp.each_char.map(&method(:bit)).freeze
}.freeze

orig_height = grid.size
orig_width = grid[0].size
raise "inconsistent width #{grid.map(&:size)}" if grid.any? { |row| row.size != orig_width }

height = orig_height + ITERS * 2
width = orig_width + ITERS * 2

# points stored in flat array at y * width + x
# avoid repeated allocation by alternating reads/writes between two arrays.
arr1 = Array.new(height * width + 1)
grid.each_with_index { |row, y|
  arr1[(y + ITERS) * width + ITERS, width] = row
}
# last element stores the state at infinity
arr1[-1] = 0
arr2 = Array.new(height * width + 1)

prev_active_height = nil
active_height = ITERS...(ITERS + orig_height)
prev_active_width = nil
active_width = ITERS...(ITERS + orig_width)

advance = -> {
  prev_active_height = active_height
  active_height = ((active_height.begin - 1)...(active_height.end + 1))
  prev_active_width = active_width
  active_width = ((active_width.begin - 1)...(active_width.end + 1))
}

step2 = ->(verbose: false) {
  advance[]
  enhance(enhance_rule, width, arr1, arr2, active_height, active_width, prev_active_height, prev_active_width)
  printarr(arr2, width, active_height, active_width) if verbose
  advance[]
  enhance(enhance_rule, width, arr2, arr1, active_height, active_width, prev_active_height, prev_active_width)
  printarr(arr1, width, active_height, active_width) if verbose
}

# points with opposite polarity as the infinite space.
# positive if infinite space is off, negative if infinite space is on.
count = ->arr { arr.count(arr[-1] ^ 1) * (arr[-1] != 0 ? -1 : 1)}

step2[verbose: verbose]
puts count[arr1]

(ITERS / 2 - 1).times { step2[] }
puts count[arr1]
