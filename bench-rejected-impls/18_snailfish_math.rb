require 'benchmark'

require_relative '../18_snailfish_math'
require_relative '18_snailfish_math/fixed_array'
require_relative '18_snailfish_math/string'
require_relative '18_snailfish_math/struct_linked_list'
require_relative '18_snailfish_math/tree'
require_relative '18_snailfish_math/tree_and_int'

results = {}

bench_candidates = []

bench_candidates << def struct_linked_list(fish, _)
  mag = fish[1..].reduce(SnailfishStruct.mkfish(fish[0])) { |a, b| a << SnailfishStruct.mkfish(b) }.magnitude

  max = 0
  fish.sort_by { |f| -f.sum(&:last) }.combination(2) { |a, b|
    next if potential_magnitude(a.sum(&:last) + b.sum(&:last)) <= max
    f = SnailfishStruct.mkfish(a) << SnailfishStruct.mkfish(b)
    max = [max, f.magnitude].max
    f = SnailfishStruct.mkfish(b) << SnailfishStruct.mkfish(a)
    max = [max, f.magnitude].max
  }
  max

  [mag, max]
end

bench_candidates << def array(fish, _)
  mag = magnitude(fish.map { |f| f.map(&:dup) }.reduce { |a, b| add(a, b) })

  max = 0
  fish.sort_by { |f| -f.sum(&:last) }.combination(2) { |a, b|
    next if potential_magnitude(a.sum(&:last) + b.sum(&:last)) <= max
    f = add(a.map(&:dup), b.map(&:dup))
    max = [max, magnitude(f)].max
    f = add(b.map(&:dup), a.map(&:dup))
    max = [max, magnitude(f)].max
  }

  [mag, max]
end

bench_candidates << def fixed_array(_, lines)
  fish = SnailfishFixedArray.parse(lines)
  mag = SnailfishFixedArray.magnitude(fish[1..].reduce(fish[0].dup) { |a, b| SnailfishFixedArray.add(a, b) })

  max = 0
  fish.sort_by { |f| -f.compact.sum }.combination(2) { |a, b|
    next if potential_magnitude(a.compact.sum + b.compact.sum) <= max
    f = SnailfishFixedArray.add(a.dup, b)
    max = [max, SnailfishFixedArray.magnitude(f)].max
    f = SnailfishFixedArray.add(b.dup, a)
    max = [max, SnailfishFixedArray.magnitude(f)].max
  }

  [mag, max]
end

bench_candidates << def string(pairs, lines)
  mag = SnailfishString.magnitude(lines.reduce { |a, b| SnailfishString.add(a, b) })

  max = 0
  lines.zip(pairs).sort_by { |_, p| -p.sum(&:last) }.combination(2) { |(a, pa), (b, pb)|
    next if potential_magnitude(pa.sum(&:last) + pb.sum(&:last)) <= max
    max = [max, SnailfishString.magnitude(SnailfishString.add(a, b))].max
    max = [max, SnailfishString.magnitude(SnailfishString.add(b, a))].max
  }

  [mag, max]
end

bench_candidates << def tree(pairs, lines)
  fish = lines.map { |l| SnailfishTree.parse(l) }.freeze
  mag = fish[1..].reduce(fish[0].deep_dup) { |a, b| a << b }.magnitude

  max = 0
  fish.zip(pairs).sort_by { |_, p| -p.sum(&:last) }.combination(2) { |(a, pa), (b, pb)|
    next if potential_magnitude(pa.sum(&:last) + pb.sum(&:last)) <= max
    max = [max, (a.deep_dup << b).magnitude].max
    max = [max, (b.deep_dup << a).magnitude].max
  }

  [mag, max]
end

bench_candidates << def tree_and_int(pairs, lines)
  fish = lines.map { |l| SnailfishTreeAndInt.parse(l) }.freeze
  mag = fish[1..].reduce(fish[0].deep_dup) { |a, b| a << b }.magnitude

  max = 0
  fish.zip(pairs).sort_by { |_, p| -p.sum(&:last) }.combination(2) { |(a, pa), (b, pb)|
    next if potential_magnitude(pa.sum(&:last) + pb.sum(&:last)) <= max
    max = [max, (a.deep_dup << b).magnitude].max
    max = [max, (b.deep_dup << a).magnitude].max
  }

  [mag, max]
end

bench_candidates.shuffle!

Benchmark.bmbm { |bm|
  bench_candidates.each { |f|
    bm.report(f) { 1.times { results[f] = send(f, @fish, @lines) } }
  }
}

# Obviously the benchmark would be useless if they got different answers.
if results.values.uniq.size != 1
  results.each { |k, v| puts "#{k} #{v}" }
  raise 'differing answers'
end
