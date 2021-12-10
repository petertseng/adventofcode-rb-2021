require 'benchmark'

OPEN_MATCHING_CLOSE = {
  ?) => ?(,
  ?] => ?[,
  ?} => ?{,
  ?> => ?<,
}.each_value(&:freeze).freeze
CLOSE_MATCHING_OPEN = OPEN_MATCHING_CLOSE.invert.each_value(&:freeze).freeze
ERR_SCORE = {
  ?) => 3,
  ?] => 57,
  ?} => 1197,
  ?> => 25137,
}.freeze
COMP_SCORE = {
  ?( => 1,
  ?[ => 2,
  ?{ => 3,
  ?< => 4,
}.freeze

bench_candidates = []

# most functions return the unopened brackets.
# if a function instead returns the string that would close the unopened brackets,
# add it here.
# The time taken to convert between the two forms doesn't count against the implementation.
returns_closing_string = []

# Push opens onto a stack, pop when seeing a close.
bench_candidates << def stack_array(brackets)
  opens = []
  brackets.each_char.with_index { |c, j|
    if COMP_SCORE.has_key?(c)
      opens << c
    elsif opens.pop != OPEN_MATCHING_CLOSE.fetch(c)
      return [false, c].freeze
    end
  }
  [true, opens.join.freeze].freeze
end

# The same, but using a string as the stack.
bench_candidates << def stack_str(brackets)
  opens = ''
  brackets.each_char.with_index { |c, j|
    if COMP_SCORE.has_key?(c)
      opens << c
    else
      return [false, c].freeze if opens[-1] != OPEN_MATCHING_CLOSE.fetch(c)
      opens.slice!(-1)
    end
  }
  [true, opens.freeze].freeze
end

PAIRS = %w(() [] {} <>).map(&:freeze).freeze

# Repeatedly delete paired brackets.
bench_candidates << def delete_many_of_one_kind(brackets)
  brackets = brackets.dup
  while PAIRS.map { |b| brackets.gsub!(b, '') }.any?
    # do nothing; condition mutates s
  end
  # If there is any close bracket, the first one is the first illegal.
  # Otherwise, the remaining string is the incomplete string.
  bad = brackets.each_char.find(&ERR_SCORE)
  [!bad, bad || brackets.freeze].freeze
end

PAIRS_RE = Regexp.union(PAIRS)

# Repeatedly delete paired brackets.
bench_candidates << def delete_many_of_any_kind(brackets)
  brackets = brackets.dup
  while brackets.gsub!(PAIRS_RE, '')
    # do nothing; condition mutates s
  end
  # If there is any close bracket, the first one is the first illegal.
  # Otherwise, the remaining string is the incomplete string.
  bad = brackets.each_char.find(&ERR_SCORE)
  [!bad, bad || brackets.freeze].freeze
end

CLOSING = Regexp.union(ERR_SCORE.keys)

# Previous strategy can terminate early:
# Consider the leftmost close bracket.
# Everything to its left is an open bracket, by definition.
# If leftmost close bracket is a mismatch, immediately terminate.
# If it matches, remove it and look for the next one.
bench_candidates << def delete_leftmost(brackets)
  brackets = brackets.dup
  pos = 1
  while pos = brackets.index(CLOSING, pos - 1)
    if OPEN_MATCHING_CLOSE[brackets[pos]] == brackets[pos - 1]
      brackets.slice!(pos - 1, 2)
    else
      return [false, brackets[pos]]
    end
  end
  [true, brackets]
end

# Recursive descent, using return values only.
# Three kinds of return values:
# [nil, pos]: No error encountered, parse position
# [true, s]: Incomplete parse, brackets that would close
# [false, c]: Corrupt parse, illegal bracket
bench_candidates << def recursive_descent_ret(brackets)
  many_balanced_ret(brackets, 0)
end
returns_closing_string << bench_candidates[-1]

def many_balanced_ret(str, pos)
  while pos < str.size
    if (close_token = CLOSE_MATCHING_OPEN[str[pos]])
      # It was an open token, so look for the close token.
      status, pos = close_pair_ret(str, pos + 1, close_token)
      return [status, pos] unless status.nil?
    elsif ERR_SCORE.has_key?(str[pos])
      # It was a close token, so stop.
      break
    else raise "unknown #{str[pos]} at #{pos} of #{str}"
    end
  end

  [nil, pos]
end

def close_pair_ret(str, pos, close_token)
  status, new_pos = many_balanced_ret(str, pos)
  unless status.nil?
    new_pos << close_token if status
    return [status, new_pos]
  end

  return [true, close_token.dup] if new_pos >= str.size
  return [false, str[new_pos]] if str[new_pos] != close_token

  # Advance by 1 to consume close token
  [nil, new_pos + 1]
end

class CorruptParseError < Exception
  attr_reader :char
  def initialize(c)
    @char = c
  end
end
class IncompleteParseError < Exception
  attr_reader :str
  def initialize(str)
    @str = str
  end
end

# Recursive descent, using exceptions.
bench_candidates << def recursive_descent_exc(brackets)
  begin
    i = many_balanced_exc(brackets, 0)
  rescue CorruptParseError => e
    [false, e.char].freeze
  rescue IncompleteParseError => e
    [true, e.str].freeze
  else
    raise "no error? #{i}"
  end
end
returns_closing_string << bench_candidates[-1]

def many_balanced_exc(str, pos)
  while pos < str.size
    if (close_token = CLOSE_MATCHING_OPEN[str[pos]])
      # It was an open token, so look for the close token.
      pos = close_pair_exc(str, pos + 1, close_token)
    elsif ERR_SCORE.has_key?(str[pos])
      # It was a close token, so stop.
      break
    else raise "unknown #{str[pos]} at #{pos} of #{str}"
    end
  end

  pos
end

def close_pair_exc(str, pos, close_token)
  begin
    new_pos = many_balanced_exc(str, pos)
  rescue IncompleteParseError => e
    e.str << close_token
    raise
  end

  raise IncompleteParseError.new(close_token.dup) if new_pos >= str.size
  raise CorruptParseError.new(str[new_pos]) if str[new_pos] != close_token

  # Advance by 1 to consume close token
  new_pos + 1
end

lines = ARGF.map(&:chomp).map(&:freeze).freeze

results = {}

bench_candidates.shuffle!

Benchmark.bmbm { |bm|
  bench_candidates.each { |f|
    bm.report(f) { 10.times { results[f] = lines.map(&method(f)) } }
  }
}

returns_closing_string.each { |f|
  results[f].each_with_index { |(incomplete, s), i|
    next unless incomplete
    results[f][i] = [true, s.reverse.each_char.map { |c| OPEN_MATCHING_CLOSE.fetch(c) }.join.freeze].freeze
  }
}

# Obviously the benchmark would be useless if they got different answers.
if results.values.uniq.size != 1
  results.each { |k, v| puts "#{k} #{v}" }
  raise 'differing answers'
end
