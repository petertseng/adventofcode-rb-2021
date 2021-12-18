module SnailfishTreeAndInt
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
        return [@left, @right, 0]
      end

      if !@left.is_a?(Integer) && (l_ladd, radd, newl = @left.explode(level + 1))
        @left = newl
        if radd > 0
          if @right.is_a?(Integer)
            @right += radd
          else
            @right.add_left(radd)
          end
        end
      end

      if !@right.is_a?(Integer) && (ladd, r_radd, newr = @right.explode(level + 1))
        @right = newr
        if ladd > 0
          if @left.is_a?(Integer)
            @left += ladd
          else
            @left.add_right(ladd)
          end
        end
      end

      l_ladd || r_radd ? [l_ladd || 0, r_radd || 0, self] : nil
    end

    def split(level = 0)
      raise "bad level #{level}" if level > 3

      if @left.is_a?(Integer)
        if @left >= 10
          if level == 3
            # combined explode + split
            @right += (@left + 1) / 2
            return [@left / 2, 0].tap { @left = 0 }
          else
            # just split
            @left = Pair.new(@left / 2, (@left + 1) / 2)
            return [0, 0]
          end
        end
      elsif (ladd, radd = @left.split(level + 1))
        if radd > 0
          if @right.is_a?(Integer)
            @right += radd
          else
            @right.add_left(radd)
          end
        end
        return [ladd, 0]
      end

      if @right.is_a?(Integer)
        if @right >= 10
          if level == 3
            # combined explode + split
            @left += @right / 2
            return [0, (@right + 1) / 2].tap { @right = 0 }
          else
            # just split
            @right = Pair.new(@right / 2, (@right + 1) / 2)
            return [0, 0]
          end
        end
      elsif (ladd, radd = @right.split(level + 1))
        if ladd > 0
          if @left.is_a?(Integer)
            @left += ladd
          else
            @left.add_right(ladd)
          end
        end
        return [0, radd]
      end

      nil
    end

    def magnitude
      l = @left.is_a?(Integer) ? @left : @left.magnitude
      r = @right.is_a?(Integer) ? @right : @right.magnitude
      3 * l + 2 * r
    end

    def add_left(add)
      if @left.is_a?(Integer)
        @left += add
      else
        @left.add_left(add)
      end
    end

    def add_right(add)
      if @right.is_a?(Integer)
        @right += add
      else
        @right.add_right(add)
      end
    end

    def deep_dup
      dd = ->v { v.is_a?(Integer) ? v : v.deep_dup }
      Pair.new(dd[@left], dd[@right])
    end

    def to_s
      "[#{@left.to_s}, #{@right.to_s}]"
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
    when /[0-9]/; Integer(c)
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
