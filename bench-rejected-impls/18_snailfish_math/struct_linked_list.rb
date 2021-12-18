# Linked list of (depth, num) pairs.
# Since they know the number to their immediate left/right, explode is easy.
SnailfishStruct = Struct.new(:depth, :num, :left, :right, :tail) {
  include Enumerable

  def each(&b)
    if block_given?
      f = self
      while f
        b[f]
        f = f.right
      end
    else
      to_enum(:each)
    end
  end

  # add smallfish number to this one and reduces (mutates)
  def <<(b)
    tail.right = b
    b.left = tail
    self.tail = b.tail

    each { |f| f.depth += 1 }

    explode_or_split

    self
  end

  def explode_or_split
    # would use each here, but it's slow.

    # Explodes: Do all in one pass left to right,
    # because an explode cannot cause another to the left.
    f = self
    while f
      if f.depth >= 5
        raise "bad depth #{f.depth}" if f.depth != 5
        raise 'no right' unless f.right
        raise 'right wrong depth' unless f.right.depth == f.depth
        if (l = f.left)
          l.num += f.num
        end
        rr = f.right.right
        if rr
          rr.num += f.right.num
          rr.left = f
        else
          self.tail = f
        end
        f.right = rr
        f.depth -= 1
        f.num = 0
      end
      f = f.right
    end

    # Splits: Could keep track of which need to happen while exploding,
    # but it doesn't seem to help that much.
    # Just start from the beginning.
    f = self
    while f
      if f.num < 10
        f = f.right
        next
      end

      if f.depth >= 4
        raise "bad depth #{f.depth}" if f.depth != 4
        # explode would happen immediately after the split,
        # so combine the two steps into one.
        if (l = f.left)
          l.num += f.num / 2
        end
        if (r = f.right)
          r.num += (f.num + 1) / 2
        end
        f.num = 0
        f = l && l.num >= 10 ? l : r
      else
        f.depth += 1
        r = f.right
        f.right = SnailfishStruct.new(f.depth, f.num - f.num / 2, f, r)
        if r
          r.left = f.right
        else
          self.tail = f.right
        end
        f.num /= 2
        f = f.num >= 10 ? f : f.right
      end
    end
  end

  def to_s
    # TODO: Probably should show the brackets too
    map(&:num).join
  end

  def magnitude
    i = 0
    sum { |f|
      # binary but 0 is 3 and 1 is 2.
      mults = (0...4).map { |j| 3 - i[j] }
      # remove lower-order bits if missing depth
      mults.shift(4 - f.depth) if f.depth < 4
      # each missing level of depth takes out 2x as many slots
      i += 1 << (4 - f.depth)
      f.num * mults.reduce(:*)
    }
  end
}

# link fish to each other, returning first (which will also be told about the last)
def SnailfishStruct.mkfish(fish)
  fish = fish.map { |f| SnailfishStruct.new(*f) }
  fish.each_cons(2) { |l, r| l.right = r; r.left = l }
  fish[0].tail = fish[-1]
  fish[0]
end
