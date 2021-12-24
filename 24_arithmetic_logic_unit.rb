# z is the only value carried over between inp instructions;
# w, x, and y are all written to before they are read.
# Discovering this, this solution just tries each digit for each inp instruction.
# Collapse inputs that lead to with equal Z into two representatives (min and max),
# filter out Zs that get too large.
def brute(insts, verbose: false)
  sections = insts.slice_before { |op, _| op == :inp }.map(&:freeze).freeze
  divides_z = sections.map { |section| section.include?([:div, :z, 26]) }.freeze

  advance_digit = ->(zs, section, z_upper_bound) {
    # just for fun, keep track of how many are accepted
    newzs = Hash.new { |h, k| h[k] = {min: nil, max: nil, count: 0} }
    # Note we only need to add a count for one of the two (min, max),
    # since both of them are representative for the entire set that has this Z.
    prefixes = zs.flat_map { |z, p| [ [p[:min], z, p[:count]], [p[:max], z, 0] ] }.uniq(&:first).sort
    prefixes.each { |prefix, z, count|
      (1..9).each { |d|
        input = prefix * 10 + d
        newz = run(section, d, z)
        next if newz > z_upper_bound
        newzs[newz][:min] ||= input
        newzs[newz][:max] = input
        newzs[newz][:count] += count
      }
    }
    newzs
  }

  cands = {0 => {min: 0, max: 0, count: 1}}
  z_upper_bound = 0

  sections.each_with_index { |section, n|
    if divides_z[n]
      z_upper_bound /= 26
    else
      z_upper_bound *= 26
      z_upper_bound += 25
    end
    cands = advance_digit[cands, section, z_upper_bound]

    puts "#{n + 1}: #{cands.size} #{cands.keys.minmax} (<= #{z_upper_bound})" if verbose
  }

  cands[0].values_at(:max, :min, :count)
end

def run(insts, inp, z)
  regs = {w: 0, x: 0, y: 0, z: z}
  resolve = ->a { a.is_a?(Integer) ? a : regs[a] }
  insts.each { |op, arg1, arg2|
    case op
    when :inp; regs[arg1] = inp
    when :add; regs[arg1] += resolve[arg2]
    when :mul; regs[arg1] *= resolve[arg2]
    when :div; regs[arg1] /= resolve[arg2]
    when :mod; regs[arg1] %= resolve[arg2]
    when :eql; regs[arg1] = (regs[arg1] == resolve[arg2] ? 1 : 0)
    else raise "bad inst #{op} #{arg1} #{arg2}"
    end
  }
  regs[:z]
end

# MONAD enforces relations between seven pairs of digits.
# For digits where xplus is positive, unconditionally z = z * 26 + w + yplus[i].
# For digits where xplus is negative, z /= 26 as long as w == z % 26 + xplus[i].
# To get a final z=0, pairs of digits must differ by the appropriate values determined by x/y.
def infer_pair(insts, verbose: false)
  xplus = []
  yplus = []

  arg = ->(inst, op, dst) {
    raise "#{inst} wasn't expected #{op} #{dst}" if inst[0] != op || inst[1] != dst
    inst[2]
  }

  insts.each_slice(18) { |section|
    raise "#{section[0]} not input" if section[0] != [:inp, :w]

    divz = arg[section[4], :div, :z]
    x = arg[section[5], :add, :x]

    if divz == 26
      raise "divide z by 26 should be <= 0 not #{x}" if x > 0
    elsif divz == 1
      raise "divide z by 1 should >= 10 not #{x}" if x < 10
    else raise "bad divided z by #{divz}"
    end

    xplus << x
    yplus << arg[section[15], :add, :y]
  }

  diffs = expected_diffs(xplus, yplus)

  if verbose
    p xplus
    p yplus
    p diffs
  end

  max = Array.new(14)
  min = Array.new(14)
  count = 1
  diffs.each { |i, j, d|
    if d < 0
      i, j = j, i
      d *= -1
    end
    count *= 9 - d
    max[j] = 9
    max[i] = 9 - d
    min[i] = 1
    min[j] = 1 + d
  }
  [max.join, min.join, count]
end

def expected_diffs(xplus, yplus)
  rel = []
  pending = []
  xplus.zip(yplus).each_with_index { |(x, y), i|
    if x <= 0
      y, previ = pending.pop
      rel << [previ, i, y + x]
    else
      pending << [y, i]
    end
  }
  raise "pending #{pending}" unless pending.empty?
  rel
end

brutearg = ARGV.delete('-b')
verbose = ARGV.delete('-v')

insts = ARGF.map { |line|
  op, *args = line.split
  args.map! { |a|
    case a
    when /\A-?\d+\z/; Integer(a)
    when ?w; :w
    when ?x; :x
    when ?y; :y
    when ?z; :z
    else raise "bad #{a} in #{line}"
    end
  }
  args.unshift(op.to_sym).freeze
}.freeze

max, min, count = brutearg ? brute(insts, verbose: verbose) : infer_pair(insts, verbose: verbose)

puts count if verbose
puts max
puts min
