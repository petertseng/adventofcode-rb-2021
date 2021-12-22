require 'benchmark'

require_relative '../22_reactor_reboot'

class Cube
  def -(c)
    return [self] unless intersects?(c)

    inter = self & c

    cands = []
    # X out, Y all, Z all
    cands << Cube.new(x.begin..(inter.x.begin - 1), y, z) if x.begin < inter.x.begin
    cands << Cube.new((inter.x.end + 1)..x.end, y, z) if x.end > inter.x.end
    # X in, Y out, Z all
    cands << Cube.new(inter.x, y.begin..(inter.y.begin - 1), z) if y.begin < inter.y.begin
    cands << Cube.new(inter.x, (inter.y.end + 1)..y.end, z) if y.end > inter.y.end
    # X in, Y in, Z out
    cands << Cube.new(inter.x, inter.y, z.begin..(inter.z.begin - 1)) if z.begin < inter.z.begin
    cands << Cube.new(inter.x, inter.y, (inter.z.end + 1)..z.end) if z.end > inter.z.end
    cands
  end
end

results = {}

bench_candidates = []

bench_candidates << def split(cubeinsts)
  cubes = []

  cubeinsts.each { |onoff, cube|
    if onoff
      unless (inters = cubes.select { |c| c.intersects?(cube) }).empty?
        # Subtract intersections with this cube before adding.
        # Thus, cubes only contains non-intersection cubes.
        cubes.concat(inters.reduce([cube]) { |cs, c|
          cs.flat_map { |cc| cc - c }
        })
      else
        # Can just add it (no intersections).
        cubes << cube
      end
    else
      # Subtract from all.
      intersected, cubes = cubes.partition { |c| c.intersects?(cube) }
      cubes.concat(intersected.flat_map { |c| c - cube })
    end
  }

  cubes.sum(&:size)
end

bench_candidates << def inclusion_exclusion(cubeinsts)
  # key: cube
  # val: either +1 or -1 (multiplier we want to apply to cube's volume)
  cubes = Hash.new(0)

  cubeinsts.each { |onoff, cube|
    update = Hash.new(0)
    deletes = []
    cubes.each { |k, v|
      next unless k.intersects?(cube)
      if cube.superset?(k)
        deletes << k
      else
        update[k & cube] -= v
      end
    }
    deletes.each { |d| cubes.delete(d) }
    # on: just add 1.
    # off: do nothing.
    # on+off intersection is correct: the +1 was canceled with a -1.
    # off+off intersection is correct: the -1 was canceled with a +1.
    update[cube] += 1 if onoff
    cubes.merge!(update) { |_, v1, v2| v1 + v2 }
    cubes.select! { |k, v| v != 0 }
  }

  cubes.sum { |k, v| k.size * v }
end

bench_candidates << def inclusion_exclusion_no_delete(cubeinsts)
  # key: cube
  # val: either +1 or -1 (multiplier we want to apply to cube's volume)
  cubes = Hash.new(0)

  cubeinsts.each { |onoff, cube|
    update = Hash.new(0)
    cubes.each { |k, v|
      next unless k.intersects?(cube)
      update[k & cube] -= v
    }
    # on: just add 1.
    # off: do nothing.
    # on+off intersection is correct: the +1 was canceled with a -1.
    # off+off intersection is correct: the -1 was canceled with a +1.
    update[cube] += 1 if onoff
    cubes.merge!(update) { |_, v1, v2| v1 + v2 }
    cubes.select! { |k, v| v != 0 }
  }

  cubes.sum { |k, v| k.size * v }
end

bench_candidates << def count_reverse(cubeinsts)
  cubeinsts = cubeinsts.reverse

  count = ->(i, cube) {
    raise "shouldn't happen" if cube.size == 0

    cubeinsts[i..-1].each_with_index { |(inston, instcube), j|
      next unless instcube.intersects?(cube)

      # relevant instruction.
      return (inston ? (cube & instcube).size : 0) + (cube - instcube).sum { |sub|
        count[i + j + 1, sub]
      }
    }

    # no relevant instruction found
    0
  }

  cubes = cubeinsts.map(&:last)
  minmax = ->sym { Range.new(*cubes.map(&sym).flat_map { |r| [r.begin, r.end] }.minmax) }
  xr = minmax[:x]
  yr = minmax[:y]
  zr = minmax[:z]

  count[0, Cube.new(xr, yr, zr)]
end

bench_candidates << def count_forward(cubeinsts)
  count = ->(i, on, cube) {
    return 0 if cube.size == 0

    cubeinsts[i..-1].each_with_index { |(inston, instcube), j|
      next if inston == on
      next unless instcube.intersects?(cube)

      # relevant instruction.
      return count[i + j + 1, inston, cube & instcube] + (cube - instcube).sum { |sub|
        count[i + j + 1, on, sub]
      }
    }

    # no relevant instruction found
    on ? cube.size : 0
  }

  cubes = cubeinsts.map(&:last)
  minmax = ->sym { Range.new(*cubes.map(&sym).flat_map { |r| [r.begin, r.end] }.minmax) }
  xr = minmax[:x]
  yr = minmax[:y]
  zr = minmax[:z]

  count[0, false, Cube.new(xr, yr, zr)]
end

KD = Struct.new(:cube, :children, :on) {
  def []=(k, v)
    return if !k.intersects?(cube)
    if k.superset?(cube)
      self.on = v
      self.children = []
      return
    end

    if children.empty?
      return if on == v

      if cube.x.begin < k.x.begin && cube.x.end >= k.x.begin
        create_child(k.x.begin, :x)
      elsif cube.x.begin <= k.x.end && cube.x.end > k.x.end
        create_child(k.x.end + 1, :x)
      elsif cube.y.begin < k.y.begin && cube.y.end >= k.y.begin
        create_child(k.y.begin, :y)
      elsif cube.y.begin <= k.y.end && cube.y.end > k.y.end
        create_child(k.y.end + 1, :y)
      elsif cube.z.begin < k.z.begin && cube.z.end >= k.z.begin
        create_child(k.z.begin, :z)
      elsif cube.z.begin <= k.z.end && cube.z.end > k.z.end
        create_child(k.z.end + 1, :z)
      else
        raise "pretty sure this doesn't happen but if it does I guess just remove this raise?"
        self.on = v
      end
    end

    children.each { |child| child[k] = v }
  end

  def create_child(bound, dim)
    xr1 = cube.x
    yr1 = cube.y
    zr1 = cube.z
    xr2 = cube.x
    yr2 = cube.y
    zr2 = cube.z
    case dim
    when :x
      xr1 = cube.x.begin..(bound - 1)
      xr2 = bound..cube.x.end
    when :y
      yr1 = cube.y.begin..(bound - 1)
      yr2 = bound..cube.y.end
    when :z
      zr1 = cube.z.begin..(bound - 1)
      zr2 = bound..cube.z.end
    else raise "bad #{dim}"
    end

    self.children = [
      KD.new(Cube.new(xr1, yr1, zr1), [], on),
      KD.new(Cube.new(xr2, yr2, zr2), [], on),
    ]
  end

  def onsize
    children.empty? ? (on ? cube.size : 0) : children.sum(&:onsize)
  end
}

bench_candidates << def kd(cubeinsts)
  cubes = cubeinsts.map(&:last)
  minmax = ->sym { Range.new(*cubes.map(&sym).flat_map { |r| [r.begin, r.end] }.minmax) }
  xr = minmax[:x]
  yr = minmax[:y]
  zr = minmax[:z]

  kd = KD.new(Cube.new(xr, yr, zr), [], false)
  cubeinsts.each { |onoff, cube|
    kd[cube] = onoff
  }

  kd.onsize
end

bench_candidates << def sweep(cubeinsts)
  # with a better implementation of a sorted set, perf might be better
  sorted_insert = ->(arr, el) {
    # use if using sorted_delete
    #sortkey = el[1] * cubeinsts.size + el[3]
    #if (idx = (0...arr.size).bsearch { |i| arr[i][1] * cubeinsts.size + arr[i][3] >= sortkey })
    sortkey = el[1]
    if (idx = (0...arr.size).bsearch { |i| arr[i][1] >= sortkey })
      arr.insert(idx, el)
    else
      arr << el
    end
  }
  # too slow, slower than just reject! on t
  sorted_delete = ->(arr, k, t) {
    sortkey = k * cubeinsts.size + t
    return unless (idx = (0...arr.size).bsearch { |i| arr[i][1] * cubeinsts.size + arr[i][3] >= sortkey })
    to_delete = arr[idx]
    return if to_delete[1] != k || to_delete[3] != t
    arr.delete_at(idx)
  }

  sweepz = ->zs {
    maxt = 0
    maxtstatus = 0
    onoffs = {}

    prev_z = 0
    length = 0

    zs.each { |onoff, z, type, i|
      length += maxtstatus * (z - prev_z)
      prev_z = z

      case type
      when :start
        onoffs[i] = onoff
        if i > maxt
          maxt = i
          maxtstatus = onoff ? 1 : 0
        end
      when :end
        onoffs.delete(i)
        if i == maxt
          maxt = onoffs.keys.max || 0
          maxtstatus = onoffs[maxt] ? 1 : 0
        end
      end
    }

    length
  }

  sweepy = ->ys {
    zs = []

    prev_y = 0
    area = 0

    ys.each { |onoff, y, type, i, z|
      length = sweepz[zs]
      area += length * (y - prev_y)
      prev_y = y

      case type
      when :start
        sorted_insert[zs, [onoff, z.begin, :start, i]]
        sorted_insert[zs, [onoff, z.end + 1, :end, i]]
        #zs << [onoff, z.begin, :start, i]
        #zs << [onoff, z.end + 1, :end, i]
        #zs.sort_by! { |_, z| z }
      when :end
        #sorted_delete[zs, z.begin, i]
        #sorted_delete[zs, z.end + 1, i]
        zs.reject! { |_, _, _, j| j == i }
      end
    }

    area
  }

  xs = cubeinsts.each_with_index.flat_map { |(onoff, cube), i|
    [
      [onoff, cube.x.begin, :start, i, cube.y, cube.z],
      [onoff, cube.x.end + 1, :end, i, cube.y, cube.z],
    ]
  }.sort_by { |_, x| x }

  ys = []

  prev_x = 0
  volume = 0

  xs.each { |onoff, x, type, i, y, z|
    area = sweepy[ys]
    volume += area * (x - prev_x)
    prev_x = x

    case type
    when :start
      sorted_insert[ys, [onoff, y.begin, :start, i, z]]
      sorted_insert[ys, [onoff, y.end + 1, :end, i, z]]
      #ys << [onoff, y.begin, :start, i, z]
      #ys << [onoff, y.end + 1, :end, i, z]
      #ys.sort_by! { |_, y| y }
    when :end
      #sorted_delete[ys, y.begin, i]
      #sorted_delete[ys, y.end + 1, i]
      ys.reject! { |_, _, _, j| j == i }
    end
  }

  volume
end

bench_candidates.shuffle!

Benchmark.bmbm { |bm|
  bench_candidates.each { |f|
    bm.report(f) { 1.times { results[f] = send(f, @cubeinsts) } }
  }
}

# Obviously the benchmark would be useless if they got different answers.
if results.values.uniq.size != 1
  results.each { |k, v| puts "#{k} #{v}" }
  raise 'differing answers'
end
