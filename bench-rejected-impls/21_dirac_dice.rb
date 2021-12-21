require 'benchmark'

bench_candidates = []

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

D3_3 = dice_sum_freq(3, 3)
SCORE = 21

bench_candidates << def count_turns(orig_pos1, orig_pos2)
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
            new_turn_player[new_score * 10 + new_pos] += freq * rollfreq
          end
        }
      }
      turns_win << wins_this_turn
      turns_not_win << new_turn_player.each_value.sum
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

bench_candidates << def turn_by_turn(orig_pos1, orig_pos2)
  # key: score * 10 + pos - 1, val: num universes
  p1s = Hash.new(0)
  p2s = Hash.new(0)
  p1s[orig_pos1 - 1] = 1
  p2s[orig_pos2 - 1] = 1
  p1s.freeze
  p2s.freeze

  wins = [0, 0]

  advance_player = ->(turn_player, other_player, win_idx) {
    new_turn_player = Hash.new(0)
    other_unis = other_player.sum(&:last)

    turn_player.each { |scorepos, freq|
      score, pos = scorepos.divmod(10)
      D3_3.sum { |roll, rollfreq|
        new_pos = (pos + roll) % 10
        new_score = score + new_pos + 1
        if new_score >= SCORE
          wins[win_idx] += other_unis * freq * rollfreq
        else
          new_turn_player[new_score * 10 + new_pos] += freq * rollfreq
        end
      }
    }
    new_turn_player.freeze
  }

  until p1s.empty? && p2s.empty?
    p1s = advance_player[p1s, p2s, 0]
    #puts "p1 moves, now #{wins} #{p1s}"
    p2s = advance_player[p2s, p1s, 1]
    #puts "p2 moves, now #{wins} #{p2s}"
  end

  wins.max
end

bench_candidates << def pos_score_cache(orig_pos1, orig_pos2)
  cache = Array.new((10 * SCORE) ** 2)

  wins = ->(turn_pos, turn_score, other_pos, other_score) {
    cache[((turn_score * 10 + turn_pos) * SCORE + other_score) * 10 + other_pos] ||= begin
      local_wins = [0, 0]
      D3_3.each { |roll, rollfreq|
        new_pos = (turn_pos + roll) % 10
        new_score = turn_score + new_pos + 1
        if new_score >= SCORE
          local_wins[0] += rollfreq
        else
          future_wins = wins[other_pos, other_score, new_pos, new_score]
          local_wins[0] += future_wins[1] * rollfreq
          local_wins[1] += future_wins[0] * rollfreq
        end
      }
      local_wins.freeze
    end
  }

  wins[orig_pos1 - 1, 0, orig_pos2 - 1, 0].max
end

pos1, pos2 = if ARGV.size == 2
  ARGV.map(&method(:Integer))
else
  ARGF.map { |l|
    raise "bad #{l} doesn't include position" unless (idx = l.index('position: '))
    Integer(l[(idx + 'position: '.size)..-1])
  }.tap { |x| raise "expected two integers not #{x}" if x.size != 2 }.freeze
end

results = {}

bench_candidates.shuffle!

Benchmark.bmbm { |bm|
  bench_candidates.each { |f|
    bm.report(f) { 10.times { results[f] = send(f, pos1, pos2) } }
  }
}

# Obviously the benchmark would be useless if they got different answers.
if results.values.uniq.size != 1
  results.each { |k, v| puts "#{k} #{v}" }
  raise 'differing answers'
end
