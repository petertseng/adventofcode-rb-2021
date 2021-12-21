def game_deterministic(*poses)
  # pos stores actual position - 1 so modding is less of a pain
  pos = poses.map(&:pred)
  score = [0, 0]

  0.step { |t|
    i = t % 2

    #   (3 * t + 1 - 1) % 100 + 1
    # + (3 * t + 2 - 1) % 100 + 1
    # + (3 * t + 3 - 1) % 100 + 1
    # simplifies to:

    pos[i] = (pos[i] + (((9 * t + 3) % 100) + 3)) % 10
    score[i] += pos[i] + 1

    return score[1 - i] * (t + 1) * 3 if score[i] >= 1000
  }
end

# precompute these to save on time
# doing it this way is overkill for 3d3, but helps for more dice.
def dice_sum_freq(dice, faces)
  # notice that since there are only 10 positions on the board,
  # we can take the rolls mod 10.
  roll_freqs = (1..faces).map { |d| d % 10 }.tally

  dice.times.reduce({0 => 1}) { |freq, _|
    freq.each_with_object(Hash.new(0)) { |(prev_roll, prev_freq), new_freq|
      roll_freqs.each { |new_roll, roll_freq|
        new_freq[(prev_roll + new_roll) % 10] += prev_freq * roll_freq
      }
    }
  }.freeze
end

dice, faces = if (darg = ARGV.find { |arg| arg.match?(/\A\d+d\d+/) })
  ARGV.delete(darg).split(?d).map(&method(:Integer))
else
  [3, 3]
end

D3_3 = dice_sum_freq(dice, faces)
SCORE = 21

def game_dirac(orig_pos1, orig_pos2)
  turns_to_win = ->orig_pos {
    turns_win = []
    turns_not_win = []
    # key: score * 10 + pos - 1, val: num universes
    turn_player = Hash.new(0)
    turn_player[orig_pos - 1] = 1
    turn_player.freeze
    until turn_player.empty?
      new_turn_player = Hash.new(0)
      wins_this_turn = 0
      not_wins_this_turn = 0
      turn_player.each { |scorepos, freq|
        score, pos = scorepos.divmod(10)
        D3_3.each { |roll, rollfreq|
          new_pos = (pos + roll) % 10
          new_score = score + new_pos + 1
          if new_score >= SCORE
            wins_this_turn += freq * rollfreq
          else
            not_wins_this_turn += freq * rollfreq
            new_turn_player[new_score * 10 + new_pos] += freq * rollfreq
          end
        }
      }
      turns_win << wins_this_turn
      turns_not_win << not_wins_this_turn
      turn_player = new_turn_player.freeze
    end
    [turns_win.freeze, turns_not_win.freeze]
  }

  turns_win1, turns_not_win1 = turns_to_win[orig_pos1]
  turns_win2, turns_not_win2 = turns_to_win[orig_pos2]

  wins1 = turns_win1.zip([0] + turns_not_win2).sum { |wins_turn1, not_wins_turn2|
    wins_turn1 * not_wins_turn2
  }
  wins2 = turns_win2.zip(turns_not_win1).sum { |wins_turn2, not_wins_turn1|
    wins_turn2 * (not_wins_turn1 || 0)
  }

  [wins1, wins2].max
end

pos1, pos2 = if ARGV.size == 2
  ARGV.map(&method(:Integer))
else
  ARGF.map { |l|
    raise "bad #{l} doesn't include position" unless (idx = l.index('position: '))
    Integer(l[(idx + 'position: '.size)..-1])
  }.tap { |x| raise "expected two integers not #{x}" if x.size != 2 }.freeze
end

puts game_deterministic(pos1, pos2)
puts game_dirac(pos1, pos2)
