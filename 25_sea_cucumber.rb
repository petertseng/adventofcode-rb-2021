# Store cucumbers in two arbitrary-precision integers,
# one per herd.
#
# Moving them is done by bit shifts.
#
# In this implementation, the top-left is the most-significant,
# followed by the rest of its row,
# with the bottom-right being least-significant.
east = 0
south = 0
width = nil
height = 0
ARGF.each_line(chomp: true) { |line|
  width ||= line.size
  raise "inconsistent width #{line.size} != #{width}" if line.size != width
  height += 1

  line.each_char { |c|
    east <<= 1
    south <<= 1
    case c
    when ?>; east |= 1
    when ?v; south |= 1
    when ?. # ok
    else raise "bad #{c}"
    end
  }
}

size = height * width

each_row = height.times.reduce(0) { |a, c| a << width | 1 }
each_col = (1 << width) - 1

left_col = (1 << (width - 1)) * each_row
right_col = 1 * each_row
top_row = each_col << (size - width)
bottom_row = 1 * each_col

#showmask = ->bits {
#  s = bits.to_s(2).rjust(size, ?0)
#  raise "#{s} too long" if s.size > size
#  s.each_char.each_slice(width) { |r| puts r.join }
#}

#puts 'left'
#showmask[left_col]
#puts 'right'
#showmask[right_col]
#puts 'top'
#showmask[top_row]
#puts 'bottom'
#showmask[bottom_row]

# wrapping shifts:
shleft = ->bits { (bits & ~left_col) << 1 | (bits & left_col) >> (width - 1) }
shright = ->bits { (bits & ~right_col) >> 1 | (bits & right_col) << (width - 1) }
shup = ->bits { (bits & ~top_row) << width | (bits & top_row) >> (size - width) }
shdown = ->bits { (bits & ~bottom_row) >> width | (bits & bottom_row) << (size - width) }

#puts 'left wrapped'
#showmask[shleft[left_col]]
#showmask[shleft[right_col]]
#puts 'right wrapped'
#showmask[shright[right_col]]
#showmask[shright[left_col]]
#puts 'up wrapped'
#showmask[shup[top_row]]
#showmask[shup[bottom_row]]
#puts 'down wrapped'
#showmask[shdown[bottom_row]]
#showmask[shdown[top_row]]

1.step { |n|
  # Can move east:
  # 000110
  # 001100 left
  # 000010 x & ~left
  moving_east = east & ~shleft[east | south]
  east = east & ~moving_east | shright[moving_east]

  # Can move south:
  # same but with up instead of left
  moving_south = south & ~shup[east | south]
  south = south & ~moving_south | shdown[moving_south]

  break puts n if moving_east == 0 && moving_south == 0
}
