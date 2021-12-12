ROOMID_START = 0
ROOMID_END = 2

# IDs to each location.
#
# Temporarily assign big caves to negative numbers.
# Then compress paths in/out of big caves by directly connecting all pairs of rooms connected by then.
#
# Some pairs of small caves will thus have multiple paths between them:
# (a-B B-d a-C C-d results in two paths between a-d)
# To save work for repeated edges,
# keep a tally and multiply results by how many times that edge occurs.
def neighs(io)
  have_start = false
  have_end = false
  smalls = 2
  bigs = 0
  ids = {}

  id = ->s {
    ids[s] ||= case s
    when 'start'
      have_start = true
      ROOMID_START
    when 'end'
      have_end = true
      ROOMID_END
    else
      if s.match?(/\A[a-z]+\z/)
        smalls += 1
      elsif s.match?(/\A[A-Z]+\z/)
        -(bigs += 1)
      else
        raise "#{s} neither uppercase nor lowercase"
      end
    end
  }

  neighs = Hash.new { |h, k| h[k] = [] }
  io.each_line(chomp: true) { |line|
    l, r = line.split(?-, 2)
    idl = id[l]
    idr = id[r]
    raise "two big rooms adjacent #{line}" if idl < 0 && idr < 0
    # Don't add the start as a destination... unless it's a big room, in which case do.
    # Don't add big rooms as a destination.
    neighs[idl] << idr if (idr != ROOMID_START || idl < 0) && idr >= 0
    neighs[idr] << idl if (idl != ROOMID_START || idr < 0) && idl >= 0
  }

  raise 'no start' unless have_start
  raise 'no end' unless have_end

  # compress bigs
  (1..bigs).each { |big|
    smalls = neighs[-big]
    smalls.each { |a|
      neighs[a] << a if a != ROOMID_START
    }
    smalls.combination(2) { |a, b|
      neighs[a] << b if b != ROOMID_START
      neighs[b] << a if a != ROOMID_START
    }
  }

  [ids.invert.freeze, neighs.select { |k, v| k >= 0 }.transform_values { |v| v.tally.freeze }.freeze]
end

verbose = ARGV.delete('-v')

room_name, neighs = neighs(ARGF)
puts neighs.to_h { |k, vs| [room_name[k], vs.transform_keys(&room_name)] } if verbose

room_bits = room_name.keys.max.bit_length
room_mask = (1 << room_bits) - 1
clear_room_mask = ~(room_mask << 1)

cache = {}

# bits: rooms visited bitfield | current room ID | small repeat (1 bit)
visit = -> bits {
  cache[bits] ||= begin
    room = (bits >> 1) & room_mask

    paths = [0, 0]

    neighs.fetch(room).each { |neigh, mult|
      if neigh == ROOMID_END
        paths[bits & 1] += mult
      else
        # small room
        this_room_bit = 1 << (neigh + room_bits + 1)
        visited_here = bits & this_room_bit != 0
        next if visited_here && bits & 1 == 1
        sub0, sub1 = visit[bits & clear_room_mask | (neigh << 1) | this_room_bit | (visited_here ? 1 : 0)]
        paths[0] += sub0 * mult
        paths[1] += sub1 * mult
      end
    }

    paths.freeze
  end
}

paths = visit[ROOMID_START << 1]

puts paths[0]
puts paths.sum
