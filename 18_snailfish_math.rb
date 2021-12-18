# Snailfish are a flat array of (depth, num) pairs
DEPTH = 0
NUM = 1

def add(a, b)
  a.concat(b)
  a.each { |f| f[DEPTH] += 1 }

  explode_or_split(a)

  a
end

def explode_or_split(a)
  # Explodes: Do all in one pass left to right,
  # because an explode cannot cause another to the left.
  a.each_with_index { |f, i|
    next if f[DEPTH] < 5
    raise 'right wrong level' if a[i][DEPTH] != f[DEPTH]
    raise "bad depth #{f[DEPTH]}" if f[DEPTH] != 5

    a[i - 1][NUM] += f[NUM] if i > 0
    a[i + 2][NUM] += a[i + 1][NUM] if i + 2 < a.size

    f[DEPTH] -= 1
    f[NUM] = 0

    a.delete_at(i + 1)
  }

  # Splits: Could keep track of which need to happen while exploding,
  # but it doesn't seem to help that much.
  # Just start from the beginning.
  i = 0
  while (f = a[i])
    if f[NUM] < 10
      i += 1
      next
    end

    if f[DEPTH] >= 4
      raise "bad depth #{f[DEPTH]}" if f[DEPTH] != 4
      # explode would happen immediately after the split,
      # so combine the two steps into one.
      a[i - 1][NUM] += f[NUM] / 2 if i > 0
      a[i + 1][NUM] += (f[NUM] + 1) / 2 if i + 1 < a.size
      f[NUM] = 0
      i += (i > 0 && a[i - 1][NUM] >= 10 ? -1 : 1)
    else
      f[DEPTH] += 1
      a[i, 1] = [f, [f[DEPTH], (f[NUM] + 1) / 2]]
      f[NUM] /= 2
      i += 1 if f[NUM] < 10
    end
  end
end

def magnitude(a)
  i = 0
  a.sum { |f|
    mults = (0...4).map { |j| 3 - i[j] }
    # remove lower-order bits if missing depth
    mults.shift(4 - f[DEPTH]) if f[DEPTH] < 4
    # each missing level of depth takes out 2x as many slots
    i += 1 << (4 - f[DEPTH])
    f[NUM] * mults.reduce(:*)
  }
end

lines = ARGF.readlines(chomp: true).map(&:freeze).freeze
fish = lines.map { |line|
  depth = 0
  line.each_char.with_object([]) { |c, fs|
    case c
    when ?[; depth += 1
    when ?]; depth -= 1
    when ?,; # ok
    when /[0-9]/; fs << [depth, Integer(c)].freeze
    else raise "bad #{c}"
    end
  }.freeze
}.freeze

puts magnitude(fish.map { |f| f.map(&:dup) }.reduce { |a, b| add(a, b) })

# possible multipliers used in magnitude, and how many regular numbers can be subject to that multiplier
MULTS = (0...16).map { |i| (0...4).map { |j| 2 + i[j] }.reduce(:*) }.tally.sort.reverse.map(&:freeze).freeze

# save time by not trying fish that can't beat the best so far
# since value is never gained, only lost (via exploding at the ends),
# sum of initial values allows us to calculate an upper bound on magnitude.
def potential_magnitude(total_value)
  MULTS.sum { |m, freq|
    val = total_value.clamp(0..(freq * 9))
    total_value -= val
    val * m
  }
end

max = 0
fish.sort_by { |f| -f.sum(&:last) }.combination(2) { |a, b|
  next if potential_magnitude(a.sum(&:last) + b.sum(&:last)) <= max
  f = add(a.map(&:dup), b.map(&:dup))
  max = [max, magnitude(f)].max
  f = add(b.map(&:dup), a.map(&:dup))
  max = [max, magnitude(f)].max
}
puts max

#export for benchmark
@fish = fish
@lines = lines
