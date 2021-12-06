lines = ARGF.each_line.map { |line|
  # "x1,y1 -> x2,y2" becomes [x1, y1, x2, y2]
  line.split(' -> ', 2).flat_map { |x| x.split(?,, 2).map(&method(:Integer)) }.freeze
}.freeze

lines = lines.map { |x1, y1, x2, y2|
  if x1 == x2
    # vert: x, yrange
    [:vert, x1, Range.new(*[y1, y2].sort)].freeze
  elsif y1 == y2
    # horiz: y, xrange
    [:horiz, y1, Range.new(*[x1, x2].sort)].freeze
  else
    # diag: dy, yintercept, xrange, yrange
    (xa, ya), (xb, yb) = [[x1, y1], [x2, y2]].sort
    dy = ya > yb ? -1 : 1
    raise "not 45 #{line}" if ya + dy * (xb - xa) != yb
    [:diag, dy, (ya - dy * xa), xa..xb, Range.new(*[y1, y2].sort)].freeze
  end
}.group_by(&:first).tap { |h| %i(vert horiz diag).each { |s| h[s] ||= [] } }.each_value(&:freeze).freeze

module RangeIntersection refine Range do
  def intersection(other)
    [self.begin, other.begin].max..[self.end, other.end].min
  end
end end

using RangeIntersection

def range_union(intervals)
  return [] if intervals.empty?
  intervals.sort_by!(&:begin)
  prev_min = intervals[0].begin
  prev_max = intervals[0].end
  intervals.each_with_object([]) { |i, merged|
    if i.begin > prev_max + 1
      merged << (prev_min..prev_max)
      prev_min = i.begin
      prev_max = i.end
    else
      prev_max = [prev_max, i.end].max
    end
  } << (prev_min..prev_max)
end

def range_union_of_intersections(intervals)
  return [] if intervals.empty?
  intervals.sort_by!(&:begin)
  prev_min = intervals[0].begin
  prev_max = intervals[0].end
  range_union(intervals[1..].each_with_object([]) { |i, inters|
    if i.begin > prev_max + 1
      prev_min = i.begin
      prev_max = i.end
    else
      inters << i.intersection(prev_min..prev_max)
      prev_max = [prev_max, i.end].max
    end
  })
end

def union_covers?(intervals, point)
  idx = (0...intervals.size).bsearch { |i| intervals[i].end >= point }
  #puts "#{idx} among #{intervals} (#{intervals[idx]}) could cover #{point}" if intervals.size > 1
  idx && intervals[idx].cover?(point)
end

# Compute overlaps between lines of same orientation.

t = Time.now

vert_2plus = lines[:vert].group_by { |_, x| x }.transform_values { |verts|
  #u2 = range_union(verts.map { |_, _, yr| yr })
  #puts "verts at x=#{x}: #{u2.sum(&:size)} total in #{u2.size} parts, #{u.sum(&:size)} overlaps in #{u.size} parts"
  range_union_of_intersections(verts.map { |_, _, yr| yr }).freeze
}.select { |_, v| !v.empty? }.freeze

horiz_2plus = lines[:horiz].group_by { |_, y| y }.transform_values { |horizes|
  #u2 = range_union(horizes.map { |_, _, xr| xr })
  #puts "horizes at y=#{y}: #{u2.sum(&:size)} total in #{u2.size} parts, #{u.sum(&:size)} overlaps in #{u.size} parts"
  range_union_of_intersections(horizes.map { |_, _, xr| xr }).freeze
}.select { |_, v| !v.empty? }.freeze

puts "same orientation in #{Time.now - t}"

# Intersections between vertical and horizontal should:
# add 1 to the count if caused by 1 vertical and 1 horizontal
# add 0 to the count if caused by 2+ vertical and 1 horizontal or 1 vertical and 2+ horizontal
# add -1 to the count if caused by 2+ vertical and 2+ horizontal

t = Time.now

# Sweep-line over X
# Events:
#   Horizontal lines' endpoints correspond to Add Y and Remove Y events.
#   Vertical lines' X coordinates cause a Intersect event over their entire Y range.
# Represented as [X, event_type, Y]
events = lines[:horiz].group_by { |_, y| y }.flat_map { |y, horizes|
  range_union(horizes.map { |_, _, xr| xr }).flat_map { |xr|
    [[xr.begin, :add_y, y].freeze, [xr.end, :rm_y, y].freeze]
  }
}
events.concat(lines[:vert].group_by { |_, x| x }.flat_map { |x, verts|
  range_union(verts.map { |_, _, yr| yr }).map { |yr|
    [x, :inter, yr].freeze
  }
})

puts "created #{events.size} events in #{Time.now - t}"

t = Time.now

# Event priority is Add, Intersect, Remove, since ranges are inclusive.
prio = {add_y: 0, inter: 1, rm_y: 2}
events.sort_by! { |x, type| (x << 2) | prio.fetch(type) }
events.freeze

puts "sorted #{events.size} events in #{Time.now - t}"

vh = 0
vvhh = 0

t = Time.now

y_count = Hash.new(0)
events.each { |x, type, arg|
  case type
  when :add_y
    y_count[arg] += 1
  when :rm_y
    new_count = (y_count[arg] -= 1)
    y_count.delete(arg) if new_count == 0
  when :inter
    y_count.keys.each { |y|
      next unless arg.cover?(y)
      h2 = union_covers?(horiz_2plus[y] || [], x)
      v2 = union_covers?(vert_2plus[x] || [], y)
      if h2 && v2
        vvhh += 1
      elsif !h2 && !v2
        vh += 1
      end
    }
  else raise "bad event #{type}"
  end
}

puts "events done in #{Time.now - t}"

vsum = vert_2plus.values.sum { |v| v.sum(&:size) }
hsum = horiz_2plus.values.sum { |v| v.sum(&:size) }
puts "vv #{vsum} + hh #{hsum} + vh #{vh} - vvhh #{vvhh}"
p vsum + hsum + vh - vvhh
