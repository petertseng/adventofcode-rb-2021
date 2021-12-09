require 'benchmark'

require_relative '../lib/union_find'
require_relative '../09_smoke_basin'

bench_candidates = []

bench_candidates << def bfs(heights, lows)
  height = heights.size
  width = heights[0].size
  lows.map { |pos| basin(heights, height, width, pos).size }
end

bench_candidates << def uf(heights, _)
  height = heights.size
  width = heights[0].size
  poses = 0...(height * width)
  uf = UnionFind.new(poses)

  heights.each_with_index { |r, y|
    r.each_with_index { |val, x|
      next if val == 9
      pos = y * width + x
      uf.union(pos, pos + 1) if x + 1 < width && r[x + 1] != 9
      uf.union(pos, pos + width) if y + 1 < height && heights[y + 1][x] != 9
    }
  }

  basins = Hash.new(0)
  poses.each { |pos|
    next if heights.dig(*pos.divmod(width)) == 9
    basins[uf.find(pos)] += 1
  }
  basins.values
end

results = {}

Benchmark.bmbm { |bm|
  bench_candidates.each { |f|
    bm.report(f) { 10.times { results[f] = send(f, @heights, @lows).sort } }
  }
}

# Obviously the benchmark would be useless if they got different answers.
if results.values.uniq.size != 1
  results.each { |k, v| puts "#{k} #{v}" }
  raise 'differing answers'
end
