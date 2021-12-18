module SnailfishTree
  class Pair
    def initialize(l, r)
      @left = l
      @right = r
    end

    # NB: dups the right, but not self
    def <<(f)
      p = Pair.new(self, f.deep_dup)
      p.explode
      while p.split
        # side effect
      end
      p
    end

    # Explodes: Do all in one pass left to right,
    # because an explode cannot cause another to the left.
    def explode(level = 0)
      if level >= 4
        raise "bad level #{level}" if level != 4
        return [@left.magnitude, @right.magnitude, Num.new(0)]
      end

      if (l_ladd, radd, newl = @left.explode(level + 1))
        @left = newl
        @right.add_left(radd) if radd > 0
      end

      if (ladd, r_radd, newr = @right.explode(level + 1))
        @right = newr
        @left.add_right(ladd) if ladd > 0
      end

      l_ladd || r_radd ? [l_ladd || 0, r_radd || 0, self] : nil
    end

    def split(level = 0)
      raise "bad level #{level}" if level >= 4

      if (ladd, radd, newl = @left.split(level + 1))
        @left = newl
        @right.add_left(radd) if radd > 0
        return [ladd, 0, self]
      end

      if (ladd, radd, newr = @right.split(level + 1))
        @right = newr
        @left.add_right(ladd) if ladd > 0
        return [0, radd, self]
      end

      nil
    end

    def magnitude
      3 * @left.magnitude + 2 * @right.magnitude
    end

    def add_left(add)
      @left.add_left(add)
    end

    def add_right(add)
      @right.add_right(add)
    end

    def deep_dup
      Pair.new(@left.deep_dup, @right.deep_dup)
    end

    def to_s
      "[#{@left.to_s}, #{@right.to_s}]"
    end
  end

  class Num
    def initialize(v)
      @v = v
    end

    def explode(_)
      nil
    end

    def split(level)
      if level > 4
        raise "bad level #{level}"
      elsif level == 4
        # combined explode + split
        @v >= 10 && [@v / 2, (@v + 1) / 2, self].tap { @v = 0 }
      else
        # just split
        @v >= 10 && [0, 0, Pair.new(Num.new(@v / 2), Num.new((@v + 1) / 2))]
      end
    end

    def add_left(add)
      @v += add
    end

    def add_right(add)
      @v += add
    end

    def magnitude
      @v
    end

    def deep_dup
      Num.new(@v)
    end

    def to_s
      @v.to_s
    end
  end

  module_function

  def parse(s)
    s = s.chars
    inner_parse(s).tap {
      raise "unparsed #{s}" unless s.empty?
    }
  end

  def inner_parse(s)
    case c = s.shift
    when /[0-9]/; Num.new(Integer(c))
    when ?,; inner_parse(s)
    when ?[
      l = inner_parse(s)
      r = inner_parse(s)
      Pair.new(l, r).tap {
        c = s.shift
        raise "#{c} wasn't close bracket" if c != ?]
      }
    else raise "unknown #{c} at #{s}"
    end
  end
end
