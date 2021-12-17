xmin, xmax, ymin, ymax, *bad = if ARGV.size == 4
  ARGV.map(&method(:Integer))
elsif ARGV.size == 2 && ARGV.all? { |arg| arg.include?(?.) }
  ARGV.flat_map { |arg| arg.split(/\.+/) }.map(&method(:Integer))
else
  ARGF.read.scan(/-?\d+/).map(&method(:Integer))
end
raise "extra args #{bad}" unless bad.empty?

xr = xmin..xmax
yr = ymin..ymax

# part 1:
# X velocity is whatever lets you stop in the X dimension within the target,
# which gives Y time to grow as much as it can.
# For Y to grow as much as it can, shoot such that you hit ymin one step after y=0
# The points you hit immediately before y = 0 are vy0, 0, and -vy0 - 1.
# This means you'd best shoot at vy0 = abs(ymin) - 1, and your max height is that triangular number.
# (For the example with ymin = -10, shoot at vy0 = 9, answer is (1..9).sum == 45)
#
# For this to work, there must be an x velocity that allows us to stall within the target.
# Check for this first before applying this solution.
# The condition "a triangular number exists within the X range" is necessary.
# It's also necessary to make sure that that we give Y enough time to grow.

def triangular(n)
  n * (n + 1) / 2
end

def triangular_in_range(xmin, xmax)
  vx = ((xmin * 2) ** 0.5).to_i - 1
  x = triangular(vx)
  raise "overshot #{xmin}" if x >= xmin
  x += (vx += 1) while x < xmin
  x <= xmax ? vx : nil
end

# if fired upward, first negative Y occurs at 2 * vy0 + 1
puts (t = triangular_in_range(xmin, xmax)) && t <= (-ymin - 1) * 2 + 1 ? triangular(-ymin - 1) : "I don't know"

# part 2:
#
# Do the two axes independently:
# Calculate for each Y the interval of times T at which it reaches the target.
# Calculate for each X the interval of times T at which it reaches the target.
# Take the cartesian product and count how many have nonempty interval intersection.
#
# As we'll see later, make the intersection counting fast by doing a sweep line.

# For given initial y velocity, at which times is it in range of target?
def ts_y(vy0, yr)
  if vy0 > 0
    # speed this up by skipping all the time it spends above y=0
    # if fired at vy0 = 2, we have (t, p, v):
    # (1, 2, +1)
    # (2, 3, +0)
    # (3, 3, -1)
    # (4, 2, -2)
    # (5, 0, -3)
    #t = 2 * vy0 + 1
    #vy = -vy0 - 1
  else
    #t = 0
    #vy = vy0
  end

  tmin = t_of_y(yr.end, vy0).ceil
  tmax = t_of_y(yr.begin, vy0).floor

  raise "y #{vy0} tmin #{tmin} isn't min" if yr.cover?(y_of_t(tmin - 1, vy0))
  raise "y #{vy0} tmax #{tmax} isn't max" if yr.cover?(y_of_t(tmax + 1, vy0))

  return if tmin > tmax

  until y_of_t(tmin, vy0) <= yr.end
    puts "y #{vy0} tmin #{tmin} is out of target (#{yr} vs #{y_of_t(tmin, vy0)}), adjusting"
    tmin += 1
  end
  until y_of_t(tmax, vy0) >= yr.begin
    puts "y #{vy0} tmax #{tmax} is out of target (#{yr} vs #{y_of_t(tmax, vy0)}), adjusting"
    tmax -= 1
  end

  return if tmin > tmax

  tmin..tmax
end

def y_of_t(t, v0)
  v0 * t - t * (t - 1) / 2
end

def t_of_y(y, v0)
  # solve the quadratic equation in y_of_t
  # (easiest to multiply by 2)
  b = 2 * v0 + 1
  d = (b ** 2 - 8 * y) ** 0.5
  raise "#{y} #{v0}: other solution #{(b - d) / 2} should be negative" if b > d
  (b + d) / 2
end

def ts_x(vx0, xr, tmax_y)
  # never reach
  return unless (tmin = t_of_x(xr.begin, vx0)&.ceil)

  raise "x #{vx0} tmin #{tmin} isn't min" if xr.cover?(x_of_t(tmin - 1, vx0))

  # reach xmin but not xmax means we stall
  if (tmax = t_of_x(xr.end, vx0)&.floor)
    raise "x #{vx0} tmax #{tmax} isn't max" if xr.cover?(x_of_t(tmax + 1, vx0))
  else
    tmax = tmax_y
  end

  return if tmin > tmax

  until x_of_t(tmin, vx0) >= xr.begin
    puts "x #{vx0} tmin #{tmin} is out of target (#{xr} vs #{x_of_t(tmin, vx0)}), adjusting"
    tmin += 1
  end
  until x_of_t(tmax, vx0) <= xr.end
    puts "x #{vx0} tmax #{tmax} is out of target (#{xr} vs #{x_of_t(tmax, vx0)}), adjusting"
    tmax -= 1
  end

  return if tmin > tmax

  tmin..tmax
end

def x_of_t(t, v0)
  triangular(v0) - triangular((v0 - t).clamp(0..))
end

def t_of_x(x, v0)
  # same equation as y, but need to check it reaches,
  # and take b - d instead
  return if triangular(v0) < x
  b = 2 * v0 + 1
  d = (b ** 2 - 8 * x) ** 0.5
  (b - d) / 2
end

# Sweep line over t << 2:
# Also consider begins (0) before ends (2)
# It doesn't matter which order we consider Y (0) and X (1),
# but we do need to keep them separate.
events = Hash.new(0)

# time intervals for y velocities:
current = ymin
while current < -ymin
  unless (i = ts_y(current, yr))
    current += 1
    next
  end
  same_len = if current < 0
    first_different = ((current + 1)..0).bsearch { |vy| ts_y(vy, yr) != i }
    first_different - current
  else
    1
  end
  events[i.begin << 2] += same_len
  events[i.end << 2 | 2] += same_len
  current += same_len
end

# time intervals for x velocities:
current = 1
try_chunk_x = false
tmax = -ymin * 2
while current <= xmax
  unless (i = ts_x(current, xr, tmax))
    current += 1
    next
  end
  try_chunk_x ||= ts_x(current + 1, xr, tmax) == i
  same_len = if try_chunk_x
    first_different = ((current + 1)..xmax).bsearch { |vx| ts_x(vx, xr, tmax) != i } || xmax + 1
    first_different - current
  else
    1
  end
  events[i.begin << 2 | 1] += same_len
  events[i.end << 2 | 3] += same_len
  current += same_len
end

active = [0, 0]

# Sweep line counts overlaps by keeping count of number of active intervals of each type (X, Y)
puts events.sort.sum { |event, freq|
  # t = event >> 2
  xy = event & 1
  if event & 2 == 2
    # interval end
    active[xy] -= freq
    0
  else
    # interval start (intersects with all active intervals of the other type)
    active[xy] += freq
    active[xy ^ 1] * freq
  end
}
