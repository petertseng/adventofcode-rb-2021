# reduced snailfish numbers are stored in arrays of size 16.
# pairs of indices separated by 1 << (4 - depth) represent elements at that depth.
# If both are occupied, it's a pair.
# If only the smaller one is occupied, it's a number.
# (only the larger one being occupied is an illegal state).
# Examples:
# if indices 0 and 1 are both occupied, that's a pair at depth 4.
# if index 0 is occupied but 1 isn't, that's a number at depth 4.
# if index 0 is occupied but 2 isn't, that's a number at depth 3.
# if index 0 is occupied but 4 isn't, that's a number at depth 2.
# if index 0 is occupied but 8 isn't, that's a number at depth 1.
# if index 8 is occupied but 12 isn't, that's a number at depth 2.
#
# when snailfish numbers have just been added, the same rules apply
# except to arrays of size 32, and indices separated by 1 << (5 - depth).

module SnailfishFixedArray
  module_function

  def parse(lines)
    lines.map { |line|
      depth = 0
      i = 0
      line.each_char.with_object(Array.new(16)) { |c, fs|
        case c
        when ?[; depth += 1
        when ?]; depth -= 1
        when ?,; # ok
        when /[0-9]/;
          fs[i] = Integer(c)
          i += 1 << (4 - depth)
        else raise "bad #{c}"
        end
      }.freeze
    }.freeze
  end

  def add(a, b)
    a.concat(b)
    explode(a)
    (0...16).each { |i|
      raise "bad #{a} has odd index #{i} occupied" if a[i * 2 + 1]
      a[i] = a[i * 2]
    }
    a.pop(16)
    split(a)
    a
  end

  # Explodes: Do all in one pass left to right,
  # because an explode cannot cause another to the left.
  def explode(a)
    prev_num = nil
    pending_right = nil
    pending_right_after = nil

    a.each_with_index { |x, i|
      next unless x

      if pending_right && i >= pending_right_after
        x = a[i] += pending_right
        pending_right = nil
      end

      # adjacent indices occupied means pair at depth 5.
      if (right = a[i + 1])
        a[prev_num] += x if prev_num
        a[i] = 0
        a[i + 1] = nil
        pending_right = right
        pending_right_after = i + 2
      end

      prev_num = i
    }
  end

  # Splits: Could keep track of which need to happen while exploding,
  # but it doesn't seem to help that much.
  # Just start from the beginning.
  def split(a)
    i = 0
    prev_num = nil
    while i < 16
      unless (x = a[i])
        i += 1
        next
      end
      unless x >= 10
        prev_num = i
        i += 1
        next
      end

      # can split to +8: 0
      # can split to +4: 0, 8
      # can split to +2: 0, 4, 8, 12
      # can split to +1: all evens
      # two equivalent ways of saying this:
      # divisible by delta * 2
      # no bits in delta * 2 - 1 set

      if (split_to = [8, 4, 2, 1].find { |j| i.nobits?((j << 1) - 1) && i + j < 16 && !a[i + j] })
        a[i + split_to] = (x + 1) / 2
        a[i] /= 2
        if a[i] < 10
          prev_num = i
          i += 1
        end
      else
        # explode would happen immediately after the split,
        # so combine the two steps into one.
        a[prev_num] += x / 2 if prev_num
        a[i + 1] += (x + 1) / 2 if i + 1 < 16
        a[i] = 0
        if prev_num && a[prev_num] >= 10
          i = prev_num
          prev_num = (prev_num - 1).downto(0).find { |j| a[j] }
        else
          prev_num = i
          i += 1
        end
      end
    end
  end

  def magnitude(a)
    a.each_with_index.sum { |x, i|
      next 0 unless x
      # to determine depth, check which elements that would be my pairs aren't there.
      # 0 needs to check 8, 4, 2, 1.
      # 8 (1000) needs to check 12, 10, 9 (+4, +2, +1)
      # 4 (0100) needs to check 6, 5 (+2, +1)
      # etc.

      depth = 4
      [1, 2, 4, 8].each { |delta|
        break if i & delta != 0
        depth -= 1 unless a[i + delta]
      }
      mults = (0...4).map { |j| 3 - i[j] }
      mults.shift(4 - depth) if depth < 4
      x * mults.reduce(:*)
    }
  end
end
