depths = ARGF.map(&method(:Integer)).freeze

[1, 3].each { |delta|
  puts (delta...depths.size).count { |i| depths[i - delta] < depths[i] }
}
