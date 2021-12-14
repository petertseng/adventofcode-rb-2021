poly = ARGF.readline("\n\n", chomp: true)
raise "bad polymer #{poly}" unless poly.match?(/\A[A-Z]+\z/)
rule = ARGF.to_h { |line|
  l, r = line.chomp.split(' -> ', 2)
  raise "bad #{l} in #{line}" unless l.size == 2
  raise "bad #{r} in #{line}" unless r.size == 1
  [l, r]
}.freeze

poly2 = poly.each_char.each_cons(2).map(&:join).tally
poly = poly.each_char.tally
poly.default = 0

[10, 30].each { |n|
  n.times {
    poly2 = poly2.each_with_object(Hash.new(0)) { |(k, v), newpoly2|
      if (insert = rule[k])
        newpoly2[k[0] + insert] += v
        newpoly2[insert + k[1]] += v
        poly[insert] += v
      else
        # Doesn't actually happen in our inputs,
        # but you never know, it could!
        newpoly2[k] += v
      end
    }
  }
  puts(-poly.values.minmax.reduce(:-))
}
