require 'benchmark'
require 'set'

E = 1
S = 2

bench_candidates = []

bench_candidates << def bits(grid, height, width)
  east = 0
  south = 0
  grid.flatten.each { |c|
    east <<= 1
    south <<= 1
    case c
    when E; east |= 1
    when S; south |= 1
    when nil # ok
    else raise "bad #{c}"
    end
  }

  size = height * width

  each_row = height.times.reduce(0) { |a, c| a << width | 1 }
  each_col = (1 << width) - 1

  left_col = (1 << (width - 1)) * each_row
  right_col = 1 * each_row
  top_row = each_col << (size - width)
  bottom_row = 1 * each_col

  # wrapping shifts:
  shleft = ->bits { (bits & ~left_col) << 1 | (bits & left_col) >> (width - 1) }
  shright = ->bits { (bits & ~right_col) >> 1 | (bits & right_col) << (width - 1) }
  shup = ->bits { (bits & ~top_row) << width | (bits & top_row) >> (size - width) }
  shdown = ->bits { (bits & ~bottom_row) >> width | (bits & bottom_row) << (size - width) }

  1.step { |n|
    moving_east = east & ~shleft[east | south]
    east = east & ~moving_east | shright[moving_east]

    # Can move south:
    # same but with up instead of left
    moving_south = south & ~shup[east | south]
    south = south & ~moving_south | shdown[moving_south]

    return n if moving_east == 0 && moving_south == 0
  }
end

bench_candidates << def east_south_transform_keys(grid, height, width)
  east = {}
  south = {}

  grid.each_with_index { |row, y|
    row.each_with_index { |c, x|
      case c
      when E; east[y * width + x] = true
      when S; south[y * width + x] = true
      when nil #ok
      else raise "bad #{c}"
      end
    }
  }

  east.freeze
  south.freeze

  size = width * height

  1.step { |n|
    any_moved = false
    # no transform_keys!, mutate while iterate
    east = east.transform_keys { |pos|
      x = pos % width
      target = pos + 1 - (x == width - 1 ? width : 0)
      moved = !east[target] && !south[target]
      any_moved ||= moved
      moved ? target : pos
    }.freeze
    south = south.transform_keys { |pos|
      target = (pos + width) % size
      moved = !east[target] && !south[target]
      any_moved ||= moved
      moved ? target : pos
    }.freeze
    #puts n
    #(0...height).each { |y|
    #  puts (0...width).map { |x|
    #    pos = y * width + x
    #    e = east.has_key?(pos)
    #    s = south.has_key?(pos)
    #    raise "both #{y} #{x}" if e && s
    #    e ? ?> : s ? ?v : ?.
    #  }.join
    #}
    return n unless any_moved
  }
end

bench_candidates << def combined_transform_keys(grid, height, width)
  cucumber = {}

  grid.each_with_index { |row, y|
    row.each_with_index { |c, x|
      cucumber[y * width + x] = c if c
    }
  }

  cucumber.freeze

  size = width * height

  1.step { |n|
    any_moved = false
    cucumber = cucumber.transform_keys { |pos|
      case cucumber[pos]
      when E
        x = pos % width
        target = pos + 1 - (x == width - 1 ? width : 0)
        moved = !cucumber[target]
        any_moved ||= moved
        moved ? target : pos
      when S
        x = pos % width
        target = (pos + width) % size
        right = target + 1 - (x == width - 1 ? width : 0)
        left = target - 1 + (x == 0 ? width : 0)

        moved = case cucumber[target]
        when E; !cucumber[right]
        when S; false
        when nil; cucumber[left] != E
        else raise "bad #{cucumber[target]}"
        end
        any_moved ||= moved
        moved ? target : pos
      else raise "bad #{t}"
      end
    }
    return n unless any_moved
  }
end

bench_candidates << def combined_to_h(grid, height, width)
  cucumber = {}

  grid.each_with_index { |row, y|
    row.each_with_index { |c, x|
      cucumber[y * width + x] = c if c
    }
  }

  cucumber.freeze

  size = width * height

  1.step { |n|
    any_moved = false
    cucumber = cucumber.to_h { |pos, t|
      case t
      when E
        x = pos % width
        target = pos + 1 - (x == width - 1 ? width : 0)
        moved = !cucumber[target]
        any_moved ||= moved
        [moved ? target : pos, t]
      when S
        x = pos % width
        target = (pos + width) % size
        right = target + 1 - (x == width - 1 ? width : 0)
        left = target - 1 + (x == 0 ? width : 0)

        moved = case cucumber[target]
        when E; !cucumber[right]
        when S; false
        when nil; cucumber[left] != E
        else raise "bad #{cucumber[target]}"
        end
        any_moved ||= moved
        [moved ? target : pos, t]
      else raise "bad #{t}"
      end
    }
    return n unless any_moved
  }
end

bench_candidates << def east_south_sets_map(grid, height, width)
  east = Set.new
  south = Set.new

  grid.each_with_index { |row, y|
    row.each_with_index { |c, x|
      case c
      when E; east << y * width + x
      when S; south << y * width + x
      when nil #ok
      else raise "bad #{c}"
      end
    }
  }

  size = width * height

  1.step { |n|
    any_moved = false

    # NB: Set#map doesn't give a Set by default.
    # Set#map! does, and it actually works despite the read while mutating?!
    east.map! { |pos|
      x = pos % width
      target = pos + 1 - (x == width - 1 ? width : 0)
      moved = !east.include?(target) && !south.include?(target)
      any_moved ||= moved
      moved ? target : pos
    }

    south.map! { |pos|
      target = (pos + width) % size
      moved = !east.include?(target) && !south.include?(target)
      any_moved ||= moved
      moved ? target : pos
    }

    return n unless any_moved
  }
end

bench_candidates << def east_south_sets_filter_map(grid, height, width)
  east = Set.new
  south = Set.new

  grid.each_with_index { |row, y|
    row.each_with_index { |c, x|
      case c
      when E; east << y * width + x
      when S; south << y * width + x
      when nil #ok
      else raise "bad #{c}"
      end
    }
  }

  east.freeze
  south.freeze

  size = width * height

  1.step { |n|
    any_moved = false

    removing_east = east.filter { |pos|
      x = pos % width
      target = pos + 1 - (x == width - 1 ? width : 0)
      !east.include?(target) && !south.include?(target)
    }
    any_moved ||= !removing_east.empty?
    moving_east = removing_east.map { |pos|
      x = pos % width
      pos + 1 - (x == width - 1 ? width : 0)
    }
    east = (east - removing_east) | moving_east

    moving_south = Set.new
    removing_south = Set.new
    south.each { |pos|
      target = (pos + width) % size
      next if east.include?(target) || south.include?(target)
      any_moved = true
      moving_south << target
      removing_south << pos
    }
    south = (south - removing_south) | moving_south

    return n unless any_moved
  }
end

bench_candidates << def array_of_arrays_1pass(grid, height, width)
  grid = grid.map(&:dup)

  1.step { |n|
    any_moved = false

    grid.each { |row|
      # don't set prev = row[-1] here, otherwise row[-2] might move when unable.
      # do it later.
      prev = nil
      wrap_move = !row[0] && row[-1] == E
      row.each_with_index { |c, x|
        if prev == E && !c
          any_moved = true
          row[x] = E
          row[x - 1] = nil
        end
        prev = c
      }
      if wrap_move
        any_moved = true
        row[-1] = nil
        row[0] = E
      end
    }

    (0...width).each { |x|
      prev = nil
      prev_row = nil
      wrap_move = !grid[0][x] && grid[-1][x] == S
      grid.each_with_index { |row, y|
        c = row[x]
        if prev == S && !c
          any_moved = true
          row[x] = S
          prev_row[x] = nil
        end
        prev = c
        prev_row = row
      }
      if wrap_move
        any_moved = true
        grid[-1][x] = nil
        grid[0][x] = S
      end
    }

    #c = {nil => ?., E => ?>, S => ?v}
    #grid.each { |r| puts r.map(&c).join }
    #puts

    return n unless any_moved
  }
end

bench_candidates << def array_of_arrays_3pass(grid, height, width)
  grid = grid.map(&:dup)

  1.step { |n|
    any_moved = false

    grid.each { |row|
      # calculate who can move in instead of who can move out,
      # to take advantage of negative index.
      can_move = row.each_with_index.filter_map { |c, x|
        x if !c && row[x - 1] == E
      }
      any_moved ||= !can_move.empty?
      can_move.each { |x| row[x - 1] = nil }
      can_move.each { |x| row[x] = E }
    }

    (0...width).each { |x|
      can_move = (0...height).filter { |y|
        !grid[y][x] && grid[y - 1][x] == S
      }
      any_moved ||= !can_move.empty?
      can_move.each { |y| grid[y - 1][x] = nil }
      can_move.each { |y| grid[y][x] = S }
    }

    return n unless any_moved
  }
end

bench_candidates << def flat_array(grid, height, width)
  grid = grid.flatten

  1.step { |n|
    any_moved = false

    can_move = grid.each_with_index.filter_map { |c, pos|
      x = pos % width
      # can't take advantage of negative index because wraps around into different row
      pos if !c && grid[pos - 1 + (x == 0 ? width : 0)] == E
    }
    any_moved ||= !can_move.empty?
    can_move.each { |pos|
      x = pos % width
      grid[pos - 1 + (x == 0 ? width : 0)] = nil
    }
    can_move.each { |pos| grid[pos] = E }

    can_move = grid.each_with_index.filter_map { |c, pos|
      # can take advantage of negative index
      pos if !c && grid[pos - width] == S
    }
    any_moved ||= !can_move.empty?
    can_move.each { |pos| grid[pos - width] = nil }
    can_move.each { |pos| grid[pos] = S }

    return n unless any_moved
  }
end

grid = ARGF.each_with_index.map { |line, y|
  line.chomp.each_char.with_index.map { |c, x|
    case c
    when ?>; E
    when ?v; S
    when ?.; nil
    else raise "bad #{c}"
    end
  }.freeze
}.freeze

height = grid.size
width = grid[0].size
raise "inconsistent width #{grid.map(&:size)}" if grid.any? { |row| row.size != width }

results = {}

bench_candidates.shuffle!

Benchmark.bmbm { |bm|
  bench_candidates.each { |f|
    bm.report(f) { 1.times { results[f] = send(f, grid, height, width) } }
  }
}

# Obviously the benchmark would be useless if they got different answers.
if results.values.uniq.size != 1
  results.each { |k, v| puts "#{k} #{v}" }
  raise 'differing answers'
end
