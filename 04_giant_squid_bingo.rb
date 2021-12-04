verbose = ARGV.delete('-v')

called_at = ARGF.readline("\n\n", chomp: true).split(?,).map(&method(:Integer)).freeze
# You can still play the game with duplicate called numbers,
# but calling a number a second time is meaningless.
raise "duplicates #{called_at.tally.select { |_, v| v > 1 }}" unless called_at.tally.all? { |_, v| v == 1 }

call_time = called_at.each_with_index.to_h
call_time.default = call_time.size
call_time.freeze

boards = ARGF.each_line("\n\n", chomp: true).map { |board|
  board.each_line(chomp: true).map { |l|
    l.split.map(&method(:Integer))
  }.freeze
}.freeze

# Two major approaches:
#
# 1. Iterate through called numbers.
#   Can be made fast by having each board keep a map of num -> position
#   and counters for how many unfilled cells remain in each row/column.
#   Once any counter hits zero, board is scored.
#   Runtime is O(nums called * boards)
#
# 2. Iterate through boards.
#   Can be made fast by keeping a map of number -> when it is called.
#   A row/column wins when its last number is called (max time),
#   And a board wins at the earliest of its rows/columns (min time).
#   Runtime is O(nums on each board * boards)
#
# The number of numbers called is necessarily >= the number of numbers on each board,
# otherwise no board would win.
# therefore, iterating through boards is guaranteed to be faster.
win_times = boards.map.with_index { |nums, i|
  widths = nums.map(&:size)
  raise "#{i} #{nums}: unequal width #{widths.uniq}" if widths.any? { |w| w != widths[0] }
  height = nums.size
  width = widths[0]

  # You can still play the game with duplicate numbers in boards,
  # but it'd be unfair in favour of boards with more duplicates.
  raise "#{id} #{nums}: duplicates #{nums.flatten.tally.select { |_, v| v > 1 }}" if nums.flatten.uniq.size != width * height

  win_times = Array.new(height + width, 0)
  nums.each_with_index { |row, y|
    row.each_with_index { |num, x|
      t = call_time[num]
      win_times[y] = t if t > win_times[y]
      win_times[height + x] = t if t > win_times[height + x]
    }
  }
  [win_times.min, i].freeze
}.freeze

sum_board = ->(i, t) { boards[i].flatten.select { |n| call_time[n] > t }.sum }

win_times.group_by(&:first).sort.each { |t, wins|
  puts({t: t, num: called_at[t], nwins: wins.size, wins: wins.map { |_, i|
    sum = sum_board[i, t]
    {id: i, sum: sum, score: sum * called_at[t]}
  }})
} if verbose

first_win, last_win = win_times.map(&:first).minmax

pm = ->(t, s) {
  wins = win_times.filter_map { |wt, i| i if wt == t }
  raise "more than one #{s} win: #{wins}" if wins.size > 1
  sum = sum_board[wins[0], t]
  puts "#{"(board #{wins[0]}) #{sum} * #{called_at[t]} = " if verbose}#{sum * called_at[t]}"
}

pm[first_win, :first]

raise "boards #{win_times.select { |t, _| t == last_win }.map(&:last)} never won" if last_win == call_time.size
pm[last_win, :last]
