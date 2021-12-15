require_relative 'lib/search'

# instead of closed set, just mark the distances
CLOSED = 0x10

def search(orig_risk, orig_height, orig_width, size_mult, astar: false, verbose: false)
  big_height = orig_height * size_mult
  big_width = orig_width * size_mult
  pad_width = big_width + 2
  goal = big_height * pad_width + big_width

  # precomputing is better than dynamically computing cost,
  # and padding (resulting in not having to check neighbours) is better than not padding,
  risk = expand(orig_risk, orig_height, orig_width, size_mult, 1)

  cost, path = if astar
    # A* really doesn't help here because the goal is in the corner.
    manhattan = ->pos {
      y, x = pos.divmod(pad_width)
      (y - big_height).abs + (x - big_width).abs
    }
    #Search.astar(pad_width + 1, ->pos { [-pad_width, -1, 1, pad_width].filter_map { |dpos|
    #  neighpos = pos + dpos
    #  c = risk[neighpos]
    #  [neighpos, c] if c != CLOSED
    #} }, manhattan, goal, verbose: verbose)
    astar_static_cost(pad_width + 1, pad_width, risk, manhattan, goal, verbose: verbose)
  else
    dijkstras(pad_width + 1, pad_width, risk, goal, verbose: verbose)
  end

  if verbose
    h = path.to_h { |pos| [pos, true] }.freeze
    risk.each_slice(pad_width).with_index { |l, y|
      puts l.map.with_index { |r, x| h[y * pad_width + x] ? r & ~CLOSED : ' ' }.join
    }
  end

  cost
end

def dijkstras(start, pad_width, cost, goal, verbose: false)
  g_score = Hash.new(1.0 / 0.0)
  g_score[start] = 0

  # Distances all < 9,
  # so can just use an array.
  opens = Array.new(10) { [] }
  opens[0] << start
  prev = {}

  dposes = [-pad_width, -1, 1, pad_width].freeze

  while (open = opens.shift)
    open.each { |current|
      next if cost[current] & CLOSED != 0
      cost[current] |= CLOSED

      return [g_score[current], Search.path_of(prev, current)] if current == goal

      dposes.each { |dpos|
        neighbour = current + dpos
        new_cost = cost[neighbour]
        next if new_cost & CLOSED != 0
        tentative_g_score = g_score[current] + new_cost
        next if tentative_g_score >= g_score[neighbour]

        prev[neighbour] = current if verbose
        g_score[neighbour] = tentative_g_score
        opens[new_cost - 1] << neighbour
      }
    }
    opens << []
  end

  nil
end

def astar_static_cost(start, pad_width, cost, heuristic, goal, verbose: false)
  g_score = Hash.new(1.0 / 0.0)
  g_score[start] = 0

  # With the heuristic, taking advantage of <9 distance is a little trickier.
  # But the heuristic changes by at most 1 per step, so differences can be 0-10.
  opens = Array.new(12) { [] }
  opens[0] << start
  prev = {}

  dposes = [-pad_width, -1, 1, pad_width].freeze

  while (open = opens.shift)
    open.each { |current|
      next if cost[current] & CLOSED != 0
      cost[current] |= CLOSED
      hcurr = heuristic[current]

      return [g_score[current], Search.path_of(prev, current)] if current == goal

      dposes.each { |dpos|
        neighbour = current + dpos
        new_cost = cost[neighbour]
        next if new_cost & CLOSED != 0
        tentative_g_score = g_score[current] + new_cost
        next if tentative_g_score >= g_score[neighbour]

        prev[neighbour] = current if verbose
        g_score[neighbour] = tentative_g_score
        opens[new_cost - hcurr + heuristic[neighbour]] << neighbour
      }
    }
    opens << []
  end

  nil
end

# such a shame this doesn't work, really...
# it's because paths might not only go down/right!
def dp(risk, orig_height, orig_width, size_mult)
  big_height = orig_height * size_mult
  big_width = orig_width * size_mult

  risk = expand(risk, orig_height, orig_width, size_mult, 0) if size_mult > 1

  dp = Array.new(risk.size, 0)

  (1...big_height).each { |y|
    dp[y * big_width] = risk[y * big_width] + dp[(y - 1) * big_width]
  }
  (1...big_width).each { |x|
    dp[x] = risk[x] + dp[x - 1]
  }

  (1...big_height).each { |y|
    (1...big_width).each { |x|
      dp[y * big_width + x] = risk[y * big_width + x] + [dp[(y - 1) * big_width + x], dp[y * big_width + x - 1]].min
    }
  }

  dp[-1]
end

def expand(risk, orig_height, orig_width, size_mult, pad)
  total_pad = pad * 2 * (orig_width + orig_height) * size_mult + 4 * pad * pad
  pad_width = orig_width * size_mult + pad * 2
  modrisk = Array.new(risk.size * size_mult * size_mult + total_pad, CLOSED)
  (orig_height * size_mult).times { |y|
    ypos = (y + pad) * pad_width
    yinc, y = y.divmod(orig_height)
    (orig_width * size_mult).times { |x|
      xpos = x + pad
      xinc, x = x.divmod(orig_width)
      modrisk[ypos + xpos] = 1 + ((risk[y * orig_width + x] + xinc + yinc - 1) % 9)
    }
  }
  modrisk
end

def modrisk(risk, orig_height, orig_width)
  ->(y, x) {
    yinc = y / orig_height
    xinc = x / orig_width
    base_risk = risk[((y % orig_height) * orig_width) + (x % orig_width)] + yinc + xinc
    1 + ((base_risk - 1) % 9)
  }
end

verbose2 = ARGV.delete('-vv')
verbose = verbose2 || ARGV.delete('-v')
dparg = ARGV.delete('-d')
astar = ARGV.delete('-a')
risk = ARGF.map { |line| line.chomp.chars.map(&method(:Integer)).freeze }
height = risk.size
width = risk[0].size
raise "inconsistent width #{risk.map(&:size)}" if risk.any? { |row| row.size != width }
risk = risk.flatten.freeze

if dparg
  puts dp(risk, height, width, 1)
  puts dp(risk, height, width, 5)
else
  puts search(risk, height, width, 1, astar: astar, verbose: verbose)
  puts search(risk, height, width, 5, astar: astar, verbose: verbose2)
end
