module SnailfishString
  NUM = ?0.freeze..?9.freeze

  module_function

  def add(a, b)
    f = "[#{a},#{b}]"
    explode_or_split(f)
    f
  end

  def explode_or_split(s)
    depth = 0
    prev_num = nil
    pending_right = nil
    i = -1

    # Explodes: Do all in one pass left to right,
    # because an explode cannot cause another to the left.
    while (c = s[i += 1])
      depth += 1 if c == ?[
      depth -= 1 if c == ?]
      next unless NUM.cover?(c)

      if pending_right
        num_end = [s.index(?], i), s.index(?,, i)].compact.min
        s[i...num_end] = (Integer(s[i...num_end]) + pending_right).to_s
        pending_right = nil
      end

      if depth >= 5
        raise "bad depth #{depth}" if depth != 5
        comma = s.index(?,, i + 1)
        num_len = comma - i
        rbracket = s.index(?], comma + 2)
        pending_right = Integer(s[(comma + 1)...rbracket])
        to_left = Integer(s[i, num_len])
        s[(i - 1)..rbracket] = ?0
        i -= 1
        # replaced a right bracket, so would miss a -= 1 on depth
        depth -= 1
        if prev_num
          prev_num_len = 1
          if NUM.cover?(s[prev_num - 1])
            prev_num_len += 1
            prev_num -= 1
          end
          v = (Integer(s[prev_num, prev_num_len]) + to_left).to_s
          len_diff = v.size - prev_num_len
          s[prev_num, prev_num_len] = v
          i += len_diff
        end
      end

      prev_num = i
    end

    depth = 0
    i = -1

    # Splits: Could keep track of which need to happen while exploding,
    # but it doesn't seem to help that much.
    # Just start from the beginning.
    while (c = s[i += 1])
      depth += 1 if c == ?[
      depth -= 1 if c == ?]
      next unless NUM.cover?(c)
      next unless NUM.cover?(s[i + 1])
      n = Integer(s[i, 2])

      if depth >= 4
        raise "bad depth #{depth}" if depth != 4
        # explode would happen immediately after the split,
        # so combine the two steps into one.
        #
        # I am giving up on the idea of a pending_right here.
        # Because we may need to go left to process new split+explodes,
        # we may have many pending_rights, each with their own minimum index.
        # And these minimum indices have to be adjusted each time the length changes.
        # The difficulty of getting this right was too much for me.
        # I'll just search for add the value to the right immediately.
        s[i, 2] = ?0
        if (right_num = ((i + 1)...s.size).find { |j| NUM.cover?(s[j]) })
          right_num_length = NUM.cover?(s[right_num + 1]) ? 2 : 1
          s[right_num, right_num_length] = (Integer(s[right_num, right_num_length]) + (n + 1) / 2).to_s
        end

        # When going back to the left, we may change depths,
        # and I also considered keeping a prev_num and prev_depth,
        # but keeping all of that when repeatedly going to the left was a pain.
        prev_depth = depth
        prev_num = (i - 1).downto(0).find { |j|
          c = s[j]
          prev_depth -= 1 if c == ?[
          prev_depth += 1 if c == ?]
          NUM.cover?(c)
        }
        if prev_num
          prev_num_len = 1
          if NUM.cover?(s[prev_num - 1])
            prev_num_len += 1
            prev_num -= 1
          end
          v = Integer(s[prev_num, prev_num_len]) + n / 2
          vs = v.to_s
          len_diff = vs.size - prev_num_len
          s[prev_num, prev_num_len] = vs
          if v >= 10
            depth = prev_depth
            i = prev_num - 1
          else
            i += len_diff
          end
        end
      else
        s[i, 2] = "[#{n / 2},#{(n + 1) / 2}]"
        depth += 1
        # not needed, because we're currently at the [
        #i -= 1 if n / 2 >= 10
      end
    end

    nil
  end

  def magnitude(s)
    i = 0
    depth = 0
    s.each_char.sum { |c|
      case c
      when ?[
        depth += 1
        0
      when ?]
        depth -= 1
        0
      when ?,
        0
      else
        # binary but 0 is 3 and 1 is 2.
        mults = (0...4).map { |j| 3 - i[j] }
        # remove lower-order bits if missing depth
        mults.shift(4 - depth) if depth < 4
        # each missing level of depth takes out 2x as many slots
        i += 1 << (4 - depth)
        Integer(c) * mults.reduce(:*)
      end
    }
  end
end
