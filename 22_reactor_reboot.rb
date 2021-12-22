def rangeinter(a, b)
  [a.begin, b.begin].max..[b.end, a.end].min
end

def rangeinter?(a, b)
  a.begin <= b.end && b.begin <= a.end
end

def rangesuper?(a, b)
  a.begin <= b.begin && b.end <= a.end
end

Cube = Struct.new(:x, :y, :z) {
  def intersects?(c)
    rangeinter?(x, c.x) && rangeinter?(y, c.y) && rangeinter?(z, c.z)
  end

  def &(c)
    Cube.new(rangeinter(x, c.x), rangeinter(y, c.y), rangeinter(z, c.z))
  end

  def superset?(c)
    rangesuper?(x, c.x) && rangesuper?(y, c.y) && rangesuper?(z, c.z)
  end

  def empty?
    size == 0
  end

  def size
    x.size * y.size * z.size
  end
}

range = ->(expect_coord, s) {
  coord, r = s.split(?=, 2)
  raise "bad coord #{coord} != #{expect_coord}" if coord != expect_coord
  Range.new(*r.split('..', 2).map(&method(:Integer)))
}

verbose = ARGV.delete('-v')

cubeinsts = ARGF.map { |line|
  onoff, coords = line.split(' ', 2)
  onoff = case onoff
  when 'on'; true
  when 'off'; false
  else raise "bad #{onoff}"
  end
  x, y, z = coords.split(',', 3)
  [onoff, Cube.new(range[?x, x], range[?y, y], range[?z, z]).freeze].freeze
}.freeze

# key: cube
# val: either +1 or -1 (multiplier we want to apply to cube's volume)
cubes = Hash.new(0)

cubeinsts.each_with_index { |(onoff, cube), i|
  update = Hash.new(0)
  deletes = []
  cubes.each { |k, v|
    next unless k.intersects?(cube)
    if cube.superset?(k)
      deletes << k
    else
      update[k & cube] -= v
    end
  }
  deletes.each { |d| cubes.delete(d) }
  # on: just add 1.
  # off: do nothing.
  # on+off intersection is correct: the +1 was canceled with a -1.
  # off+off intersection is correct: the -1 was canceled with a +1.
  update[cube] += 1 if onoff
  cubes.merge!(update) { |_, v1, v2| v1 + v2 }
  cubes.select! { |k, v| v != 0 }
  puts "cube #{i + 1} regions #{cubes.size} volume #{cubes.sum { |k, v| k.size * v }}" if verbose
}

r50 = -50..50
c50 = Cube.new(r50, r50, r50)
puts cubes.sum { |k, v| (k & c50).size * v }
puts cubes.sum { |k, v| k.size * v }

# export for benchmark
@cubeinsts = cubeinsts
