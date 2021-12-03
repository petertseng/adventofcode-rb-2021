# frozen_string_literal: true

# k = number of bits in each value,
# n = number of values
#
# The non-sorting solutions take time O(k * n)
# The sorting solutions take time O((k + n) log n)
# Which one is better thus depends on the relative sizes of k and n.
# For the small advent of code inputs, sorting solutions are better,
# but the difference isn't noticeable because the inputs are so small.
# For other inputs, it'll depend.

require 'benchmark'

bench_candidates = []
impl_sort = Hash.new
impl_as_str = Hash.new

bench_candidates << def num_sort(nums, len, keep_most:)
  (len - 1).downto(0) { |i|
    zeroes = (0...nums.size).bsearch { |j| nums[j][i] != 0 } || nums.size
    ones = nums.size - zeroes
    nums = nums[(ones < zeroes) ^ keep_most ? zeroes.. : 0...zeroes]
    return nums[0] if nums.size == 1
  }
  raise "#{nums.size} candidates left"
end
impl_sort[bench_candidates[-1]] = true

# Not that much faster, and more code.
bench_candidates << def num_sort_no_slice(nums, len, keep_most:)
  left = 0
  right = nums.size
  (len - 1).downto(0) { |i|
    first_one = (left...right).bsearch { |j| nums[j][i] != 0 } || right
    zeroes = first_one - left
    ones = right - left - zeroes
    if (ones < zeroes) ^ keep_most
      left = first_one
    else
      right = first_one
    end
    return nums[left] if right - left == 1
  }
  raise "#{right - left} candidates left"
end
impl_sort[bench_candidates[-1]] = true

bench_candidates << def num_partition(nums, len, keep_most:)
  (len - 1).downto(0) { |i|
    zeroes, ones = nums.partition { |n| n[i] == 0 }
    # ones = zeroes: most means keep 1s
    # ones > zeroes: most means keep 1s
    # ones < zeroes: most means keep 0s
    nums = (ones.size < zeroes.size) ^ keep_most ? ones : zeroes
    return nums[0] if nums.size == 1
  }
  raise "#{nums.size} candidates left"
end

bench_candidates << def num_count_and_filter(nums, len, keep_most:)
  (len - 1).downto(0) { |i|
    zeroes = nums.count { |n| n[i] == 0 }
    ones = nums.size - zeroes
    keep = (ones < zeroes) ^ keep_most ? 1 : 0
    nums = nums.select { |n| n[i] == keep }
    return nums[0] if nums.size == 1
  }
  raise "#{nums.size} candidates left"
end

# str is slightly faster, but there's no validation that the string is ^[01]+$
bench_candidates << def str_sort(nums, len, keep_most:)
  len.times { |i|
    zeroes = (0...nums.size).bsearch { |j| nums[j][i] != ?0 } || nums.size
    ones = nums.size - zeroes
    nums = nums[(ones < zeroes) ^ keep_most ? zeroes.. : 0...zeroes]
    return nums[0].to_i(2) if nums.size == 1
  }
  raise "#{nums.size} candidates left"
end
impl_as_str[bench_candidates[-1]] = true
impl_sort[bench_candidates[-1]] = true

bench_candidates << def str_partition(nums, len, keep_most:)
  len.times { |i|
    zeroes, ones = nums.partition { |n| n[i] == ?0 }
    nums = (ones.size < zeroes.size) ^ keep_most ? ones : zeroes
    return nums[0].to_i(2) if nums.size == 1
  }
  raise "#{nums.size} candidates left"
end
impl_as_str[bench_candidates[-1]] = true

# Considered a prefix tree, but I am convinced it would be slower.
# To insert into the tree, you need to examine every bit of every element.
# Most of these solutions only look at as many bits as necessary.

strs = ARGF.readlines(chomp: true).freeze
lens = strs.map(&:size).uniq
raise "unequal lengths #{lens}" if lens.size != 1
len = lens[0]

results = {}

Benchmark.bmbm { |bm|
  bench_candidates.each { |f|
    sort = impl_sort[f]
    as_str = impl_as_str[f]
    bm.report(f) { 100.times {
      nums = as_str ? strs : strs.map { |n| Integer(n, 2) }.freeze
      nums_in = sort ? nums.sort.freeze : nums
      v1 = send(f, nums_in, len, keep_most: true)
      v2 = send(f, nums_in, len, keep_most: false)
      results[f] = (v1 << len) | v2
    }}
  }
}

# Obviously the benchmark would be useless if they got different answers.
if results.values.uniq.size != 1
  results.each { |k, v| puts "#{k} #{v}" }
  raise 'differing answers'
end
