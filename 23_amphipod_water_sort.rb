require_relative 'lib/search'

# hall0, hall1,        hall2,        hall3,        hall4,        hall5, hall6
#               side0         side1         side2         side3
# notice that to the left of sideN is hall(N + 1) and to its right is hall(N + 2)

TYPES = 4

def letterid(l)
  case l
  when ?A; 0
  when ?B; 1
  when ?C; 2
  when ?D; 3
  else raise "bad #{l}"
  end
end

# position of each hallway position relative to leftmost side room
XPOS = [
  -2,
  -1,
  # A
  1,
  # B
  3,
  # C
  5,
  # D
  7,
  8,
].freeze

# which hallway positions do you pass when going from one side room to another
SIDE_TO_SIDE = [
  # 0
  [], [2], [2, 3], [2, 3, 4],
  # 1
  [2], [], [3], [3, 4],
  # 2
  [3, 2], [3], [], [4],
  # 3
  [4, 3, 2], [4, 3], [4], [],
].map(&:freeze).freeze

# which hallway positions do you pass when going from hallway to side room
HALL_TO_SIDE = [
  # 0
  [1], [1, 2], [1, 2, 3], [1, 2, 3, 4],
  # 1
  [], [2], [2, 3], [2, 3, 4],
  # 2
  [], [], [3], [3, 4],
  # 3
  [2], [], [], [4],
  # 4
  [3, 2], [3], [], [],
  # 5
  [4, 3, 2], [4, 3], [4], [],
  # 6
  [5, 4, 3, 2], [5, 4, 3], [5, 4], [5],
].map(&:freeze).freeze

# General note:
#
# Pruning deadlocked states is the big time-saver here,
# since it prevents searching branches that are ultimately futile.
# However, I'm a little unsatisfied with how I do it.
#
# I have three different sections of code all dedicated to finding different kinds of deadlocks.
# Even though some of them may find similar kinds of deadlocks,
# they find them under different circumstances.
# So all of these sections are currently necessary.
#
# I haven't been able to tie them all to a single unifying principle, and I wish I could.
#
# I do test these on all 2520 possible part 1 inputs and their part 2 expansions.
# (but not all 63063000 possible arrangements of 16)
def neigh((hall, sides), height)
  good = [0, 0, 0, 0]
  sides.each_with_index { |side, side_type|
    side.reverse_each { |type|
      if type == side_type
        good[type] += 1
      else
        break
      end
    }
  }
  good.freeze

  # Hall -> side room can only be to final destination.
  # Any legal ones should be immediately taken.
  hall.each { |pos, type|
    # won't move into its room if its room has anything that doesn't belong
    next if good[type] != sides[type].size
    # can't if path is blocked
    checks = HALL_TO_SIDE[pos * TYPES + type]
    next if checks.any? { |c| hall.has_key?(c) }

    xdist = (XPOS[pos] - type * 2).abs
    ydist = height - sides[type].size

    newside = sides.dup
    newside[type] = (sides[type].dup << type).freeze

    return [[[hall.except(pos).freeze, newside.freeze].freeze, 10 ** type * (xdist + ydist)]]
  }

  # Can any move from a side room directly into its destination side room?
  # Any legal ones should be immediately taken.
  sides.each_with_index { |side, source_side_type|
    next if side.empty?
    moving_type = side[0]
    next if moving_type == source_side_type

    # won't move into its room if its room has anything that doesn't belong
    next if good[moving_type] != sides[moving_type].size
    # can't if path is blocked
    next unless SIDE_TO_SIDE[source_side_type * TYPES + moving_type].none? { |pos| hall.has_key?(pos) }

    ydist = height - side.size + 1
    ydist += height - sides[moving_type].size
    xdist = (source_side_type - moving_type).abs * 2

    newside = sides.dup
    newside[source_side_type] = side[1..].freeze
    newside[moving_type] = (newside[moving_type].dup << moving_type).freeze

    return [[[hall, newside.freeze].freeze, 10 ** moving_type * (xdist + ydist)]]
  }

  bad = sides.zip(good).map { |side, g| side.size - g }.freeze
  sidemins = sides.map(&:min)
  sidemaxes = sides.map(&:max)

  # No moves we know we can immediately take, so we have to try all side -> hall possibilities.
  sides.each_with_index.flat_map { |side, source_side_type|
    # no need to move out of this side room (or there's nothing to move)
    next [] if side.empty? || bad[source_side_type] == 0

    # blocked on both sides.
    # (not needed for correctness as it's checked later on,
    # but checking it early avoids some more expensive operations later on)
    next [] if hall.has_key?(source_side_type + 1) && hall.has_key?(source_side_type + 2)

    # If an amphipod divides the board into two,
    # only consider moves on the side it needs to move toward.
    # Moves on the side it's moving away from can't help it get toward its destination.
    # Either it will reach its destination and the search will continue,
    # or it will be unable to and we'll know this path is doomed,
    # regardless of what happens on the other side.
    case hall[2]
    when 0
      next [] if source_side_type != 0
    when 1, 2, 3
      next [] if source_side_type == 0
    end
    case hall[3]
    when 0, 1
      next [] if source_side_type == 2 || source_side_type == 3
    when 2, 3
      next [] if source_side_type == 0 || source_side_type == 1
    end
    case hall[4]
    when 3
      next [] if source_side_type != 3
    when 0, 1, 2
      next [] if source_side_type == 3
    end

    moving_type = side[0]

    candidates = []

    # move both left and right until either:
    # path is obstructed
    # moved as far as possible
    # would deadlock
    # (remember, if we got here, we know the destination room isn't yet ready to receive)

    leftbound = 0
    # Historical note: There used to be a fourth type of deadlock detection here:
    #
    # Deadlock type 4: Two amphipods in a hall that must move past each other.
    #
    # when considering how far left to move an A,
    # look at the max letter present to the right of A's side room.
    # you can't move beyond the right of that letter's side room.
    # otherwise, neither of those letters can get into their side room.
    # examples:
    #
    # deadlocked:
    #   D   A
    # # # # # #
    # #A#B#C#D#
    #
    # not deadlocked (assuming things can move out of A's side room):
    # D     A
    # # # # # #
    # #A#B#C#D#
    #
    # not deadlocked (assuming things can move out of D's side room):
    #   D     A
    # # # # # #
    # #A#B#C#D#
    #
    # It was removed because type 2 and 3 are supersets of it,
    # so checking here didn't add any additional value.
    # Checking it here iterates through the hall a second time,
    # and the time saved about equaled the time used.
    # So just skip it and let type 2 or 3 catch these.
    #left = source_side_type + 1
    #until left < moving_type + 2
    #  leftbound = [leftbound, hall[left] + 2].max if hall.has_key?(left)
    #  left -= 1
    #end
    if hall[moving_type + 1] &.>= moving_type
      # Deadlock type 1: Three-way deadlock between two amphipods in a hallway
      # (one of which is to the immediate left of the room of the other,
      # AND which must move past the other), and one in a side room.
      #
      # example: if D is to the immediate left of the B side room, and there's a C in the B side room,
      # B can move no farther left than to the right of the C side room.
      # if it did, the D, C, and B all can't get to their final destinations:
      # the B is waiting for the C to move out of the B side room
      # the D is waiting for the B to move into the B side room
      # the C can't move to the left (blocked by D) nor into its destination (blocked by B)
      # so the bounding is the minimum between (immediate left of B side room, maximum in B side room)
      #
      # deadlocked:
      #   D B
      # # #C# # #
      # #A#B#C#D#
      #
      # not deadlocked (C will move into its side room):
      #   D   B
      # # #C# # #
      # #A#B#C#D#
      #
      # not deadlocked (C will move into its side room):
      #   C   B
      # # #D# # #
      # #A#B#C#D#
      #
      # not deadlocked (D could move to the left):
      #       B
      # # #D# # #
      # #A#B#C#D#
      bounding_letter = [sidemaxes[moving_type], hall[moving_type + 1]].compact.min
      leftbound = bounding_letter + 2 if bounding_letter + 2 > leftbound
    end
    left = source_side_type + 1
    until hall.has_key?(left) || left < leftbound
      candidates << left
      left -= 1
    end

    # same as above, exchanging min / max
    rightbound = 6
    #right = source_side_type + 2
    #until right > moving_type + 1
    #  rightbound = [rightbound, hall[right] + 1].min if hall.has_key?(right)
    #  right += 1
    #end
    if hall[moving_type + 2] &.<= moving_type
      bounding_letter = [sidemins[moving_type], hall[moving_type + 2]].compact.min
      rightbound = bounding_letter + 1 if bounding_letter + 1 < rightbound
    end
    right = source_side_type + 2
    until hall.has_key?(right) || right > rightbound
      candidates << right
      right += 1
    end

    modbad = bad.dup
    # If an amphipod moves out of its own room, it's no longer bad.
    modbad[source_side_type] -= 1

    # Deadlock type 2:
    # The three positions in between rooms can often cause deadlocks,
    # based on who just moved there.
    candidates.reject! { |cand|
      case cand
      when 2
        # Between A and B
        case moving_type
        when 0
          free_left = hall.has_key?(1) ? 0 : hall.has_key?(0) ? 1 : 2
          # Deadlocked if A moved there:
          #
          # #.. A       #
          # ###3# # # ###
          #   #A#B#C#D#
          modbad[0] > free_left
        when 2
          # #   C A     #
          # ### # # # ###
          #   #A#B#C#D#
          #
          # (both type 3 and the now-deleted type 4 will also catch this,
          # but catching it here saves type 3 from doing a bit of work)
          hall[3] == 0
        when 3
          # #   D A     #
          # ### # # # ###
          #   #A#B#C#D#
          #
          # #   D   A   #
          # ### # # # ###
          #   #A#B#C#D#
          hall[3] == 0 || hall[4] == 0
        end
      when 3
        # Between B and C
        case moving_type
        when 0
          # #   D A     #
          # ###3# # # ###
          #   #A#B#C#D#
          #
          # #   C A     #
          # ### # # # ###
          #   #A#B#C#D#
          next true if hall[2] == 2 || hall[2] == 3
          # #.. . A     #
          # ###3# # # ###
          #   #A#B#C#D#
          #
          # B doesn't block if it can move into its side room,
          # but A always blocks (blocked by whatever's in A side room),
          # and so do C and D (blocked by the A that just moved).
          doesnt_block = modbad[1] == 0 ? 1 : -1
          free_left = hall[1]&.!=(doesnt_block) ? 0 : hall[0]&.!=(doesnt_block) ? 1 : 2
          #
          # Deadlocked if too many amphipods in A room,
          # AND can't resolve the situation by moving B's from A room into B room.
          #
          # Keep in mind that even though there are three spaces,
          # moving into the one between A and B blocks the A from moving back.
          #
          # Determine whether you can move B's from A room into B room:
          # If there are too many bad in B, you can never do so (will block space between A and B).
          # Otherwise, move amphipods out of B and into the free spaces on the left.
          # After doing so, is there enough free space to uncover a B in A room who can move?
          # If there are, then it resolves the situation by moving into B room - no deadlock.
          modbad[0] > free_left && (modbad[1] > free_left || !sides[0][source_side_type == 0 ? 1 : 0, free_left - modbad[1] + 1].include?(1))
        when 1
          blocking = modbad[0] > 0 ? 0 : 1
          if hall[2] &.>= blocking
            # #   X B     #
            # ### #1# # ###
            #   #A#B#C#D#
            #
            # In this case, not even A's in the B side room will save this.
            modbad[1] > 0
          else
            free_left = if hall[1] &.>= blocking
              # # X . B     #
              # ### #2# # ###
              #   #A#B#C#D#
              1
            elsif hall[0] &.>= blocking
              # #X. . B     #
              # ### #3# # ###
              #   #A#B#C#D#
              2
            else
              # #.. . B     #
              # ### #4# # ###
              #   #A#B#C#D#
              3
            end
            # Similar to A: Deadlocked if too many amphipods in B room,
            # AND can't resolve the situation by moving A's from B room into A room.
            #
            # However, more care is required, because moving between A and B still allows the B to move back;
            # the only thing it stops is moving between A and B.
            # And placing an A there is okay if you can empty the A room.
            #
            # A non-deadlock, if all of the 3's in B are A's:
            # #D. . B     #
            # ###2#3# # ###
            #   #A#B#C#D#
            #
            # #DB A B     #
            # ### #3# # ###
            #   #A#B#C#D#
            #
            # #DB . B     #
            # ### #3# # ###
            #   #A#B#C#D#
            #
            # #DB . B     #
            # ### # # # ###
            #   #A#B#C#D#
            #
            # So I think modbad[0] > free_left is still the correct condition,
            # rather than modbad[0] > free_left - 1.
            #
            # We could use modbad[0] > free_left - 1 if we checked for A's within the first free_left of A room, maybe???
            # (the difference between > free_left and > free_left - 1 is just == free_left of course)
            #
            # It is still safe to consider A's to the left (position 0) blocking,
            # because only an A can be placed betwen A and B (position 2),
            # so either A room remains bad, or a non-A gets placed at position 1.
            #
            # As for the sides[1] check, we can subtract 1 from free_left there,
            # because placing at position 2 (between A room and B room) will block A moving from B room to A room.
            # But we also may have to subtract 1 from modbad[0] if there was an A that moved out and back.
            a_has_a = sides[0][source_side_type == 0 ? 1 : 0, free_left].include?(0)
            modbad[1] > free_left && (modbad[0] > free_left || modbad[0] == free_left && !a_has_a || !sides[1][source_side_type == 1 ? 1 : 0, free_left - 1 - (modbad[0] - (a_has_a ? 1 : 0)) + 1].include?(0))
          end
        when 2
          blocking = modbad[3] > 0 ? 3 : 2
          # Mirror of B moving here.
          if hall[4] &.<= blocking
            modbad[2] > 0
          else
            free_right = if hall[5] &.<= blocking
              1
            elsif hall[6] &.<= blocking
              2
            else
              3
            end
            d_has_d = sides[3][source_side_type == 3 ? 1 : 0, free_right].include?(3)
            modbad[2] > free_right && (modbad[3] > free_right || modbad[3] == free_right && !d_has_d || !sides[2][source_side_type == 2 ? 1 : 0, free_right - 1 - (modbad[3] - (d_has_d ? 1 : 0)) + 1].include?(3))
          end
        when 3
          # Mirror of A moving here.
          next true if hall[4] == 0 || hall[4] == 1
          doesnt_block = modbad[2] == 0 ? 2 : -1
          free_right = hall[5]&.!=(doesnt_block) ? 0 : hall[6]&.!=(doesnt_block) ? 1 : 2
          modbad[3] > free_right && (modbad[2] > free_right || !sides[3][source_side_type == 3 ? 1 : 0, free_right - modbad[2] + 1].include?(2))
        end
      when 4
        # Between C and D
        # mirror of 2 (between A and B)
        case moving_type
        when 3
          free_right = hall.has_key?(5) ? 0 : hall.has_key?(6) ? 1 : 2
          modbad[3] > free_right
        when 1
          hall[3] == 3
        when 0
          hall[3] == 3 || hall[2] == 3
        end
      else
        false
      end
    }

    # (not necessary for correctness, just avoid doing the dups if not needed)
    next [] if candidates.empty?

    newside = sides.dup
    newside[source_side_type] = side[1..].freeze
    newside.freeze
    ydist = height - side.size + 1

    candidates.filter_map { |pos|
      xdist = (XPOS[pos] - source_side_type * 2).abs
      next if deadlock?(hall, newside, pos, moving_type, height)
      [[hall.merge(pos => moving_type).freeze, newside].freeze, 10 ** moving_type * (xdist + ydist)]
    }
  }
end

# Deadlock type 3:
# Consider every pair of amphipods in the hallway,
# and whether either of them have to move past the other.
#
# Of course, we only need to check new pairs formed by what just moved;
# all other pairs stayed the same.
def deadlock?(hall, sides, moving_pos, moving_type, height)
  raise 'moved to occupied spot' if hall.has_key?(moving_pos)
  hall.any? { |other_pos, other_type|
    if other_pos < moving_pos
      left_pos = other_pos
      left_type = other_type
      right_pos = moving_pos
      right_type = moving_type
    else
      left_pos = moving_pos
      left_type = moving_type
      right_pos = other_pos
      right_type = other_type
    end

    # TODO: Maybe something can be done about these
    # (the 0/1 pair and the 5/6 pair)
    # haven't been able to find a deadlock involving them yet
    next if right_pos == 1
    next if left_pos == 5

    # 01 2 3 4 56
    #   0 1 2 3
    left_past_right = left_type >= right_pos - 1
    right_past_left = right_type <= left_pos - 2

    next true if left_past_right && right_past_left

    if left_type == right_type && left_pos == left_type + 1 && right_pos == right_type + 2
      # they are the same, and to the left and right of their own side room
      # someone in their side room can't get to their own
      # I think this only works for immediate left/right:
      #     C C
      # # # #D# #
      # #A#B#C#D#
      #
      # this situation isn't deadlocked because D can move out of the way.
      #   C   C
      # # # #D# #
      # #A#B#C#D#
      next true if sides[left_type].any? { |x| x != left_type }
    end

    next false if !left_past_right && !right_past_left

    if left_past_right
      # examples:
      # D     B
      # # #D# # #
      # #A#B#C#D#
      #
      # One space to the left:
      # Deadlocked if there are two D's in the B side room, OK if there's only one.
      #
      #   D   C
      # # # #A# #
      # #A#B#C#D#
      #
      # Doesn't matter how many spaces are to the right.
      # If the A moves left, it always blocks D.
      # If the A moves right, either it blocks D, or it moved far enough that it doesn't,
      # in which case we couldn't be in a left-past-right situation.
      free_spaces_to_left = right_type + 1 - left_pos
      right_pos >= right_type + 2 && (sides[right_type].count { |type| type >= right_pos - 1 } > free_spaces_to_left || sides[right_type].any? { |type| type <= left_pos - 2 })
    elsif right_past_left
      # Mirror of the above
      #
      #   C     A
      # # # #A# #
      # #A#B#C#D#
      free_spaces_to_right = right_pos - (left_type + 2)
      left_pos <= left_type + 1 && (sides[left_type].count { |type| type <= left_pos - 2 } > free_spaces_to_right || sides[left_type].any? { |type| type >= right_pos - 1 })
    else
      raise 'all cases should have been covered???'
    end
  }
end

def heur((hall, sides), height)
  good = [0, 0, 0, 0]
  hall.sum { |pos, type|
    xdist = (XPOS[pos] - type * 2).abs
    # y distance into side room handled later
    10 ** type * xdist
  } + sides.each_with_index.sum { |side, side_type|
    side.reverse_each { |type|
      if type == side_type
        good[type] += 1
      else
        break
      end
    }
    side.each_with_index.sum { |type, y|
      next 0 if type == side_type && side.size - good[type] <= y

      # If moving letter out of its own destination because there's a bad letter below it,
      # will move it to the side (to let the bad letter out) and back, 2 total.
      xdist = type == side_type ? 2 : (type - side_type).abs * 2
      # y distance into side room handled later
      # 1 + y out of this side room
      # and if this side room has fewer occupants than max, the difference is added,
      # because e.g. at height 4 size 2, index 0 needs to move 2 more to reach hallway,
      # compared to if height 4 size 4.
      ydist = 1 + y + height - side.size
      10 ** type * (xdist + ydist)
    }
  } + good.each_with_index.sum { |good_count, type|
    n = height - good_count
    # if 1 needs to move in, it will move distance 1
    # if 2 need to move in, 2 + 1
    # if 3 need to move in, 3 + 2 + 1
    # triangular numbers
    10 ** type * n * (n + 1) / 2
  }
end

def putsmap((hall, sides), height)
  puts '#############'
  puts ?# + (0..10).map { |x|
    next ?. unless i = XPOS.index(x - 2)
    hall[i] ? (?A.ord + hall[i]).chr : ?.
  }.join + ?#
  height.times { |y|
    l = y == 0 ? '###' : '  #'
    r = y == 0 ? '###' : ?#
    puts l + sides.map { |side|
      next ?. if height - side.size > y
      (?A.ord + side[y - height + side.size]).chr
    }.join(?#) + r
  }
  puts '  #########'
end

checkfirst = ARGV.delete('-1')
verbose = ARGV.delete('-v')

raise 'bad 1' if ARGF.readline != "#############\n"
raise 'bad 2' if ARGF.readline != "#...........#\n"
raise 'bad 3' unless m1 = ARGF.readline.match(/\A###([A-D])#([A-D])#([A-D])#([A-D])###\n\z/)
raise 'bad 4' unless m2 = ARGF.readline.match(/\A  #([A-D])#([A-D])#([A-D])#([A-D])#\n\z/)
raise 'bad 5' if ARGF.readline.chomp != '  #########'
raise 'bad 6' unless ARGF.eof?
sides = [m1.captures, m2.captures].transpose.map { |side| side.map(&method(:letterid)).freeze }.freeze

def goal(height)
  [{}.freeze, Array.new(TYPES) { |i| Array.new(height, i).freeze }.freeze].freeze
end

search = -> {
  hall = {}.freeze
  height = sides.map(&:size).max
  cost, path = Search.astar([hall, sides].freeze, ->x { neigh(x, height) }, ->x { heur(x, height) }, goal(height), verbose: verbose)
  puts cost
  path.each { |x| putsmap(x, height) } if verbose
}

search[]

sides = sides.map(&:dup)
#D#C#B#A#
#D#B#A#C#
sides[0].insert(1, 3, 3)
sides[1].insert(1, 2, 1)
sides[2].insert(1, 1, 0)
sides[3].insert(1, 0, 2)
sides.map(&:freeze).freeze

# Check candidate first moves, to see which ones are unsolvable.
# If I find any patterns and can formulate a rule that says why a position is unsolvable,
# I can use it to filter out all unsolvable positions of that class.
if checkfirst
  neighs = neigh([{}.freeze, sides], 4)
  neighs.each { |state, c|
    _, p = Search.astar(state, ->x { neigh(x, 4) }, ->x { heur(x, 4) }, goal(4))
    puts "#{p ? "\e[1;32mOK" : "\e[1;31mNO"} #{c} #{state}"
    putsmap(state, 4)
  }
end

search[]
