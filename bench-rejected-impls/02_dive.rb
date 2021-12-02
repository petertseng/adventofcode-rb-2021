require 'benchmark'

bench_candidates = []

bench_candidates << def regular(dirs)
  x = y = a = 0
  dirs.each { |l|
    dir, i = l.split(' ', 2)
    i = Integer(i)

    case dir
    when 'forward'
      x += i
      y += i * a
    when 'down'
      a += i
    when 'up'
      a -= i
    else raise "bad #{l}"
    end
  }
  [x * a, x * y]
end

# These are also known as Fenwick trees
class BinaryIndexedTree
  def initialize(max_time)
    @toggles = Array.new(max_time, 0)
    @max_time = max_time
  end

  def value_before(time)
    ret = 0
    while time > 0
      ret += @toggles[time]
      time -= time & -time
    end
    ret
  end

  def add(time, val)
    raise "time must be positive, can't be #{time}" if time <= 0
    while time < @max_time
      @toggles[time] += val
      time += time & -time
    end
  end
end

bench_candidates << def joke_fenwick(dirs)
  dirs = dirs.each_with_index.map { |l, i|
    dir, val = l.split(' ', 2)
    [dir.to_sym, Integer(val), i].freeze
  }.group_by(&:first).each_value(&:freeze).freeze

  t_max = dirs.values.sum(&:size)
  depth = BinaryIndexedTree.new(t_max + 1)

  x = y = 0

  dirs[:up].shuffle.each { |_, v, i| depth.add(i, -v) }
  dirs[:down].shuffle.each { |_, v, i| depth.add(i, v) }
  dirs[:forward].shuffle.each { |_, v, i|
    x += v
    y += v * depth.value_before(i)
  }

  [x * depth.value_before(t_max), x * y]
end

results = {}

bench_candidates.shuffle!

lines = ARGF.readlines

Benchmark.bmbm { |bm|
  bench_candidates.each { |f|
    bm.report(f) { 100.times { results[f] = send(f, lines) } }
  }
}

# Obviously the benchmark would be useless if they got different answers.
if results.values.uniq.size != 1
  results.each { |k, v| puts "#{k} #{v}" }
  raise 'differing answers'
end
