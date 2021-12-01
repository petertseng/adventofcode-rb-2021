require 'benchmark'

bench_candidates = []

bench_candidates << def index(depths)
  [1, 3].map { |delta|
    (delta...depths.size).count { |i| depths[i - delta] < depths[i] }
  }
end

bench_candidates << def zip(depths)
  [1, 3].map { |delta|
    depths[delta..-1].zip(depths).count { |a, b| a > b }
  }
end

bench_candidates << def cons_index(depths)
  [2, 4].map { |window|
    depths.each_cons(window).count { |a| a[0] < a[-1] }
  }
end

bench_candidates << def cons_first_last(depths)
  [2, 4].map { |window|
    depths.each_cons(window).count { |a| a.first < a.last }
  }
end

bench_candidates << def cons_star(depths)
  [2, 4].map { |window|
    depths.each_cons(window).count { |a, *, b| a < b }
  }
end

bench_candidates << def cons_sum_cons(depths)
  [
    depths.each_cons(2).count { |a, b| a < b },
    depths.each_cons(3).map(&:sum).each_cons(2).count { |a, b| a < b },
  ]
end

# Okay so for this one all you have to do is just sort the input and...
# what do you mean I wasn't supposed to do it this way?
bench_candidates << def joke_answer_sort(depths)
  depths = depths.each_with_index.sort_by { |a, b| [a, -b] }.map(&:freeze).freeze
  [1, 3].map { |delta|
    smaller = Array.new(depths.size)
    depths.count { |_, i| smaller[i] = true; i >= delta && smaller[i - delta] }
  }
end

depths = ARGF.map(&method(:Integer)).freeze

results = {}

bench_candidates.shuffle!

Benchmark.bmbm { |bm|
  bench_candidates.each { |f|
    bm.report(f) { 100.times { results[f] = send(f, depths) } }
  }
}

# Obviously the benchmark would be useless if they got different answers.
if results.values.uniq.size != 1
  results.each { |k, v| puts "#{k} #{v}" }
  raise 'differing answers'
end
