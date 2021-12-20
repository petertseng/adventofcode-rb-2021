ITERS = 50

# Act on a 4x4 area
# I first got this idea from askalski who first applied it to this problem.
# (see github.com/Voltara/advent2021-fast)
# The same technique is also usable in 2015 day 18.
# (You would think it is also usable in 2022 day 23, but it turns out not to be so)
#
# f e d c
# b a 9 8
# 7 6 5 4
# 3 2 1 0
#
# output bits will occupy bits 0, 1, 4, 5.
def enhance_rule_4x4(enhance_rule)
  (1 << 16).times.map { |i|
    lr = enhance_rule[(i & 0x700)  >> 2 | (i & 0x70)  >> 1 |  i & 0x7]
    ll = enhance_rule[(i & 0xe00)  >> 3 | (i & 0xe0)  >> 2 | (i & 0xe)  >> 1]
    ur = enhance_rule[(i & 0x7000) >> 6 | (i & 0x700) >> 5 | (i & 0x70) >> 4]
    ul = enhance_rule[(i & 0xe000) >> 7 | (i & 0xe00) >> 6 | (i & 0xe0) >> 5]
    ul << 5 | ur << 4 | ll << 1 | lr
  }
end

# Since the enhanced area grows each step, we can offset indices to only do two reads per write.
# output area Y, X (A) will depend on these indices of the input area:
# * upper left  corner Y - 1, X - 1 (B)
# * upper right corner Y - 1, X     (C)
# * lower left  corner Y,     X - 1 (D)
# * lower right corner Y,     X     (E)
#
# BBCC
# BAAC
# DAAE
# DDEE
#
# We can see that the area grows by a half-quad in each direction, as follows:
# Input area 0, 0 is the lower right of output area 0, 0.
# input area W, H is the upper left of output area W + 1, H + 1.
#
# Recall that bits for each quad are stored in positions 0, 1, 4, 5.
# We'll store the top two and bottom two in two separate integers.
# Move right by shifting and masking appropriately.
def enhance_4x4(enhance_rule_4x4, width, read, write, active_height, active_width)
  (0...active_height).each { |y|
    above_active = y != 0
    below_active = y + 1 < active_height
    # The left edge of each row (B and D for x = 0) is the infinite area.
    above = read[-1] * 0b101
    below = read[-1] * 0b101
    (0...active_width).each { |x|
      right_active = x + 1 < active_width
      # moving right is shifting left, because lower-order bits need to become higher-order bits when moving right.
      above = ((above << 2) & 0b11001100) | read[right_active ? (y - 1) * width + x : -1] if above_active
      below = ((below << 2) & 0b11001100) | read[right_active ?  y      * width + x : -1] if below_active

      write[y * width + x] = enhance_rule_4x4.fetch(above << 8 | below)
    }
  }

  write[-1] = enhance_rule_4x4[read[-1] == 0 ? 0 : (1 << 16) - 1]
end

def bit(c)
  case c
  when ?#; 1
  when ?.; 0
  else raise "bad #{c}"
  end
end

POPCOUNT = (1 << 16).times.map { |i| i.to_s(2).count(?1) }.freeze

def printarr(arr, width, active_height, active_width)
  if arr[-1] != 0
    # draw some border around the space I guess...
    draw_height = -2...(active_height + 2)
    draw_width = -2...(active_width + 2)
  else
    draw_height = (0...active_height)
    draw_width = (0...active_width)
  end
  draw_height.each { |y|
    l1 = ''
    l2 = ''
    draw_width.each { |x|
      border = !(0...active_height).cover?(y) || !(0...active_width).cover?(x)
      if border
        l1 << '##'
        l2 << '##'
      else
        v = arr[y * width + x]
        l1 << ((v >> 5) & 1 != 0 ? ?# : ' ')
        l1 << ((v >> 4) & 1 != 0 ? ?# : ' ')
        l2 << ((v >> 1) & 1 != 0 ? ?# : ' ')
        l2 << (v & 1 != 0 ? ?# : ' ')
      end
    }
    puts l1
    puts l2
  }
end

verbose = ARGV.delete('-v')

enhance_rule = ARGF.readline("\n\n", chomp: true).each_char.map(&method(:bit)).freeze
raise "bad enhance_rule needs to size 512 not #{enhance_rule.size}: #{enhance_rule}" if enhance_rule.size != 512

enhance_rule_4x4 = enhance_rule_4x4(enhance_rule)

grid = ARGF.map { |line|
  line.chomp.each_char.map(&method(:bit)).freeze
}.freeze

orig_height = grid.size
orig_width = grid[0].size
raise "inconsistent width #{grid.map(&:size)}" if grid.any? { |row| row.size != orig_width }

# Round up original
# grows by 1 in each direction per iteration (total 1 quad each)
height = (orig_height + 1) / 2 + ITERS
width = (orig_width + 1) / 2 + ITERS

arr1 = Array.new(height * width + 1)
grid.each_slice(2).with_index { |(row1, row2), y|
  arr1[y * width, (orig_width + 1) / 2] = row1.zip(row2 || []).each_slice(2).map { |(ul, ll), (ur, lr)|
    ul << 5 | (ur || 0) << 4 | (ll || 0) << 1 | (lr || 0)
  }
}
# last element stores the state at infinity
arr1[-1] = 0
arr2 = Array.new(height * width + 1)

active_height = (orig_height + 1) / 2
active_width = (orig_width + 1) / 2

step2 = ->(verbose: false) {
  active_height += 1
  active_width += 1
  enhance_4x4(enhance_rule_4x4, width, arr1, arr2, active_height, active_width)
  printarr(arr2, width, active_height, active_width) if verbose
  active_height += 1
  active_width += 1
  enhance_4x4(enhance_rule_4x4, width, arr2, arr1, active_height, active_width)
  printarr(arr1, width, active_height, active_width) if verbose
}

# points with opposite polarity as the infinite space.
# positive if infinite space is off, negative if infinite space is on.
count = ->arr {
  ones = arr[0..-2].compact.sum { |x| POPCOUNT[x] }
  arr[-1] != 0 ? -(4 * active_height * active_width - ones) : ones
}

step2[verbose: verbose]
puts count[arr1]

(ITERS / 2 - 1).times { step2[] }
puts count[arr1]
