ITERS = 50

@enhance_rec_cache = Array.new(ITERS) { [] }
@cache_stat = {hit: 0, miss: 0}

def enhance_rec(enhance_rule, orig, y, x, t, orig_height, orig_width, top: false)
  unless (-t...(orig_height + t)).cover?(y) && (-t...(orig_width + t)).cover?(x)
    # Out of range of actives at that time.
    return enhance_rule[0] && (enhance_rule[511] || t % 2 != 0)
  end
  return orig[y][x] if t == 0

  k = (y + t) * (orig_width + t * 2) + x + t

  # can't use ||= because false will cause a recalculation.
  unless @enhance_rec_cache[t - 1][k].nil?
    #@cache_stat[:hit] += 1
    return @enhance_rec_cache[t - 1][k]
  end

  #@cache_stat[:miss] += 1
  b = 0
  b |= 0x100 if enhance_rec(enhance_rule, orig, y - 1, x - 1, t - 1, orig_width, orig_height)
  b |=  0x80 if enhance_rec(enhance_rule, orig, y - 1, x    , t - 1, orig_width, orig_height)
  b |=  0x40 if enhance_rec(enhance_rule, orig, y - 1, x + 1, t - 1, orig_width, orig_height)
  b |=  0x20 if enhance_rec(enhance_rule, orig, y    , x - 1, t - 1, orig_width, orig_height)
  b |=  0x10 if enhance_rec(enhance_rule, orig, y    , x    , t - 1, orig_width, orig_height)
  b |=   0x8 if enhance_rec(enhance_rule, orig, y    , x + 1, t - 1, orig_width, orig_height)
  b |=   0x4 if enhance_rec(enhance_rule, orig, y + 1, x - 1, t - 1, orig_width, orig_height)
  b |=   0x2 if enhance_rec(enhance_rule, orig, y + 1, x    , t - 1, orig_width, orig_height)
  b |=   0x1 if enhance_rec(enhance_rule, orig, y + 1, x + 1, t - 1, orig_width, orig_height)

  #if t == 50 && (@prog += 1) % 1000 == 0
  #  puts "Done #{y} #{x} progress #@prog / #{(orig_width + ITERS * 2) * (orig_height + ITERS * 2)} taking #{Time.now - @tprev} since last checkpoint (#{Time.now - @tstart} total) cache sizes #{@enhance_rec_cache.map(&:size)}"
  #  @tprev = Time.now
  #end

  @enhance_rec_cache[t - 1][k] = enhance_rule[b]
end

def bit(c)
  case c
  when ?#; true
  when ?.; false
  else raise "bad #{c}"
  end
end

enhance_rule = ARGF.readline(chomp: true).each_char.map(&method(:bit)).freeze
raise "bad enhance_rule needs to size 512 not #{enhance_rule.size}: #{enhance_rule}" if enhance_rule.size != 512

ARGF.readline(chomp: true).tap { |s| raise "line 2 should be empty not #{s}" unless s.empty? }

grid = ARGF.map { |line|
  line.chomp.each_char.map(&method(:bit)).freeze
}.freeze

orig_height = grid.size
orig_width = grid[0].size
raise "inconsistent width #{grid.map(&:size)}" if grid.any? { |row| row.size != orig_width }

count = ->t {
  (-t...(orig_height + t)).sum { |y|
    (-t...(orig_width + t)).count { |x|
      enhance_rec(enhance_rule, grid, y, x, t, orig_height, orig_width, top: true)
    }
  }
}

puts count[2]
@tstart = @tprev = Time.now
@prog = 0
puts count[50]
