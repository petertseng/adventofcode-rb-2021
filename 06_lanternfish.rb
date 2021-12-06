def coeff(n, t)
  t.times.with_object(Array.new(9) { |i| i == n ? 1 : 0 }) { |i, fish|
    fish[(i + 7) % 9] += fish[i % 9]
  }.sum
end

if ARGV.delete('-g')
  [80, 256].each { |t|
    terms = (0..8).map { |i| "#{coeff(i, t)} * fish[#{i}]" }
    puts "puts #{terms.join(' + ')}"
  }
  exit(0)
end

fish = (ARGV[0]&.include?(?,) ? ARGV[0] : ARGF.read).split(?,).map(&method(:Integer)).tally.tap { |h| h.default = 0 }.freeze
raise "bad fish #{fish.keys.reject { |k| (0..8).cover?(k) }}" if fish.keys.max > 8 || fish.keys.min < 0

puts 1421 * fish[0] + 1401 * fish[1] + 1191 * fish[2] + 1154 * fish[3] + 1034 * fish[4] + 950 * fish[5] + 905 * fish[6] + 779 * fish[7] + 768 * fish[8]
puts 6703087164 * fish[0] + 6206821033 * fish[1] + 5617089148 * fish[2] + 5217223242 * fish[3] + 4726100874 * fish[4] + 4368232009 * fish[5] + 3989468462 * fish[6] + 3649885552 * fish[7] + 3369186778 * fish[8]
