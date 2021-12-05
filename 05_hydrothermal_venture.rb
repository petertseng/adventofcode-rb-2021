lines = ARGF.map { |line|
  # "x1,y1 -> x2,y2" becomes [x1, y1, x2, y2]
  line.split(' -> ', 2).flat_map { |x| x.split(?,, 2).map(&method(:Integer)) }.freeze
}.freeze

# Actually could just take the max Y, but this is shorter.
height = lines.map(&:max).max + 1

# stored as x * height + y
points = Hash.new(0)

lines90, lines45 = lines.partition { |x1, y1, x2, y2| x1 == x2 || y1 == y2 }.map(&:freeze)

lines90.each { |x1, y1, x2, y2|
  if x1 == x2
    ya, yb = [y1, y2].sort
    (ya..yb).each { |y| points[x1 * height + y] += 1 }
  else
    xa, xb = [x1, x2].sort
    (xa..xb).each { |x| points[x * height + y1] += 1 }
  end
}

puts points.count { |_, v| v > 1 }

lines45.each { |x1, y1, x2, y2|
  (xa, ya), (xb, yb) = [[x1, y1], [x2, y2]].sort
  dy = ya > yb ? -1 : 1
  raise "not 45 #{line}" if ya + dy * (xb - xa) != yb
  (xa..xb).each_with_index { |x, d| points[x * height + ya + d * dy] += 1 }
}

puts points.count { |_, v| v > 1 }
