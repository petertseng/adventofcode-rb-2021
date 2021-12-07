def min_align(crabs, candidates = Range.new(*crabs.minmax), &b)
  candidates.map { |align| align_cost(crabs, align, &b) }.min
end

def align_cost(crabs, i)
  crabs.sum { |x| yield (x - i).abs }
end

crabs = (ARGV[0]&.include?(?,) ? ARGV[0] : ARGF.read).split(?,).map(&method(:Integer)).freeze
median = crabs.sort[crabs.size / 2]
puts align_cost(crabs, median, &:itself)
mean = crabs.sum.fdiv(crabs.size)
puts min_align(crabs, [mean.floor, mean.ceil]) { |v| v * (v + 1) / 2 }
