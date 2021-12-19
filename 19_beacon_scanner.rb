REQUIRED_OVERLAPS = 12

# equivalent to N choose 2.
REQUIRED_PAIRS = (1...REQUIRED_OVERLAPS).sum

# given two sets of points, if they overlap at >= 12 points,
# returns their permutation, rotation (* -1 or * +1), and alignment (+ C)
def overlap(s1, s2, verbose: false)
  candidates = []

  [0, 1, 2].each { |xaxis|
    axis_align_indices(s1, s2, 0, xaxis, verbose: verbose).each { |xrot, xalign, is1, is2|
      # Filter down to just the points that matched,
      # to make other coordinates easier to match.
      s1_filtered = is1.map { |i| s1[i] }
      s2_filtered = is2.map { |i| s2[i] }

      ([0, 1, 2] - [xaxis]).each { |yaxis|
        axis_align(s1_filtered, s2_filtered, 1, yaxis, verbose: verbose).each { |yrot, yalign|
          # We could filter again here just as we did for xs,
          # but it doesn't seem to particularly make a difference.

          zaxis = 3 - xaxis - yaxis
          axis_align(s1_filtered, s2_filtered, 2, zaxis, verbose: verbose).each { |zrot, zalign|
            candidates << [[xaxis, yaxis, zaxis], xrot, yrot, zrot, xalign, yalign, zalign]
          }
        }
      }
    }
  }

  candidates.empty? ? nil : candidates.uniq
end

# align on an axis, returning the translation, rotation, and matching indices
def axis_align_indices(s1, s2, axis1, axis2, verbose: false)
  # note here the _idx need to account for scanners that have more than one point at that coordinate.
  axis1_idx = Hash.new { |h, k| h[k] = [] }
  s1.each_with_index { |s, i| axis1_idx[s[axis1]] << i }
  axis1 = s1.map { |s| s[axis1] }

  axis2_idx = Hash.new { |h, k| h[k] = [] }
  s2.each_with_index { |s, i| axis2_idx[s[axis2]] << i }
  axis2 = s2.map { |s| s[axis2] }

  candidates = []

  [1, -1].each { |rot|
    axis2.map!(&:-@) if rot == -1

    trs = axis1.product(axis2).map { |a, b| a - b }.tally.select { |k, v| v >= REQUIRED_OVERLAPS }.keys
    # this part would have been just trs.map { |tr| [rot, tr] }
    # but I do need to find the indices, so I need to find which elements intersected.
    trs.each { |tr|
      axis2_t = axis2.map { _1 + tr }
      inter = axis2_t & axis1
      # have to recount here, because [1, 1] & [1, 1] is just [1].
      intersz = inter.sum { |i| [axis1_idx[i].size, axis2_idx[(i - tr) * rot].size].min }
      candidates << [rot, tr, inter.flat_map(&axis1_idx), inter.flat_map { |i| axis2_idx[(i - tr) * rot] }] if intersz >= REQUIRED_OVERLAPS
    }
  }

  candidates.uniq
end

# align on an axis, returning the translation and rotation
def axis_align(s1, s2, axis1, axis2, verbose: false)
  axis1 = s1.map { |s| s[axis1] }
  axis2 = s2.map { |s| s[axis2] }
  axis1count = axis1.tally
  axis2count = axis2.tally

  candidates = []

  [1, -1].each { |rot|
    axis2.map!(&:-@) if rot == -1

    trs = axis1.product(axis2).map { |a, b| a - b }.tally.select { |k, v| v >= REQUIRED_OVERLAPS }.keys
    # you'd think this can just be trs.map { |tr| [rot, tr] },
    # but I cannot rule out the possibility of ([x], [y]*12)
    # (where a single point matches with 12 of the other set,
    # instead of 12 pairs matching each other)
    # So, I'll check every candidate shift found to make sure it actually results in 12 pairs.
    trs.each { |tr|
      axis2_t = axis2.map { _1 + tr }
      inter = axis2_t & axis1
      # have to recount here, because [1, 1] & [1, 1] is just [1].
      intersz = inter.sum { |i| [axis1count[i], axis2count[(i - tr) * rot]].min }
      candidates << [rot, tr] if intersz >= REQUIRED_OVERLAPS
    }
  }

  candidates.uniq
end

module Transform refine Array do
  def scale(x, y, z)
    map { |xx, yy, zz| [xx * x, yy * y, zz * z] }
  end

  def translate(x, y, z)
    map { |xx, yy, zz| [xx+x, yy+y, zz+z] }
  end

  def permute(x, y, z)
    map { |pt| [pt[x], pt[y], pt[z]] }
  end
end end

using Transform

Scanner = Struct.new(:i, :points, :pairwise_dist)

def dist(pos1, pos2)
  pos1.zip(pos2).sum { |x1, x2| (x1 - x2).abs }
end

verbose = ARGV.delete('-v')

scanner = ARGF.each_line("\n\n", chomp: true).map.with_index { |section, i|
  scanner, *beacons = section.lines
  raise "#{scanner} not scanner" unless scanner.include?('scanner')
  points = beacons.map { |line|
    line.split(?,).map(&method(:Integer)).freeze
  }.freeze
  Scanner.new(i, points, points.combination(2).map { |p1, p2| dist(p1, p2) }.tally.freeze).freeze
}.freeze

puts "#{scanner.size} scanners see #{scanner.map { |s| s.points.size }} = #{scanner.sum { |s| s.points.size }} points" if verbose

# inferred points of all scanners, from each individual scanner's point of view
scanner_combined = scanner.map(&:points)
# inferred positions of all scanners, from each individual scanner's point of view
scanner_pos = scanner.map { [[0, 0, 0]] }
overlap_rules = Array.new(scanner.size) { {} }

# Find all pairs that overlap
scanner.combination(2) { |s1, s2|
  # Try to avoid doing some work:
  # If by pairwise distances these scanners can't overlap in 12 points,
  # don't bother trying to compute their overlap.
  # again, recount to deal with multiple instances of the same distance
  # and [1, 1] & [1, 1] being [1]
  inter = s1.pairwise_dist.keys & s2.pairwise_dist.keys
  intersz = inter.sum { |i| [s1.pairwise_dist[i], s2.pairwise_dist[i]].min }
  next if intersz < REQUIRED_PAIRS

  next unless (o = overlap(s1.points, s2.points))
  raise "not exactly one possible overlap??? #{o}" if o.size != 1

  perm, xrot, yrot, zrot, xalign, yalign, zalign = o[0]
  reverse_perm = (0..2).map { |i| perm.index(i) }
  overlap_rules[s1.i][s2.i] = ->pts { pts.permute(*perm).scale(xrot, yrot, zrot).translate(xalign, yalign, zalign) }
  overlap_rules[s2.i][s1.i] = ->pts { pts.translate(-xalign, -yalign, -zalign).scale(xrot, yrot, zrot).permute(*reverse_perm) }

  puts "#{s1.i} #{s2.i} #{o[0]} #{forward[scanner_combined[s2.i]].count { |pt| scanner_combined[s1.i].include?(pt) }}" if verbose
}

# Get all scanners into one coordinate system.
# Just DFS and each scanner adds connected scanners' points to its own.
#
# Starting from a central scanner would save time (maybe 25%),
# but this already takes only 25% of the time compared to finding the pairs,
# so it doesn't seem worth the effort.
seen = Array.new(scanner.size)
add_scanners = ->from {
  return if seen[from]
  seen[from] = true
  overlap_rules[from].each { |k, v|
    add_scanners[k]
    scanner_combined[from] |= v[scanner_combined[k]]
    scanner_pos[from] |= v[scanner_pos[k]]
  }
}
main_scanner = 0
add_scanners[main_scanner]

raise "didn't connect all scanners #{scanner_pos[main_scanner].size}" if scanner_pos[main_scanner].size != scanner.size

puts scanner_combined[main_scanner].size

# Similarly, this is definitely doable in O(n) rather than O(n^2)
# (maximum Manhattan distance is much easier than maximum Euclidean distance)
# Take the maximum distance in any of these four combinations of dimensions:
# x + y + z, x + y - z, x - y + z, x - y - z
# but this is taking < 1% of overall runtime so it's not worth the effort.
far1, far2 = scanner_pos[main_scanner].combination(2).max_by { |pos1, pos2| dist(pos1, pos2) }
if verbose
  p far1
  p far2
end
puts dist(far1, far2)
