class UnionFind
  attr_reader :num_sets

  def initialize(things)
    @parent = things.map { |x| [x, x] }.to_h
    @rank = things.map { |x| [x, 0] }.to_h
    @num_sets = things.size
  end

  def union(x, y)
    xp = find(x)
    yp = find(y)

    return if xp == yp

    if @rank[xp] < @rank[yp]
      @parent[xp] = yp
    elsif @rank[xp] > @rank[yp]
      @parent[yp] = xp
    else
      @parent[yp] = xp
      @rank[xp] += 1
    end
    @num_sets -= 1
  end

  def find(x)
    @parent[x] = find(@parent[x]) if @parent[x] != x
    @parent[x]
  end
end
