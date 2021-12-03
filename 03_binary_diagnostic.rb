def majority_bits(nums, len)
  len.times.sum { |i|
    zeroes = nums.count { |n| n[i] == 0 }
    ones = nums.size - zeroes
    raise "equal count at #{i}" if zeroes == ones
    (ones > zeroes ? 1 : 0) << i
  }
end

def filter_by_freq(nums, len, keep_most:, verbose: false)
  num_left = {}
  (len - 1).downto(0) { |i|
    zeroes, ones = nums.partition { |n| n[i] == 0 }
    # ones = zeroes: most means keep 1s
    # ones > zeroes: most means keep 1s
    # ones < zeroes: most means keep 0s
    nums = (ones.size < zeroes.size) ^ keep_most ? ones : zeroes
    num_left[len - 1 - i] = nums.size if verbose
    if nums.size == 1
      puts num_left if verbose
      return nums[0]
    end
  }
  raise "#{nums.size} candidates left"
end

verbose = ARGV.delete('-v')
nums = ARGF.readlines(chomp: true)
lens = nums.map(&:size).uniq
raise "unequal lengths #{lens}" if lens.size != 1
len = lens[0]
nums.map! { |n| Integer(n, 2) }.freeze

pm = ->(a, b) { puts "#{"#{a} * #{b} = " if verbose}#{a * b}" }

pm[maj = majority_bits(nums, len), (1 << len) - 1 - maj]

pm[
  filter_by_freq(nums, len, keep_most: true, verbose: verbose),
  filter_by_freq(nums, len, keep_most: false, verbose: verbose),
]
