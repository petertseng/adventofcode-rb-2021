A, B, C, D, E, F, G = (0..6).map { |i| 1 << i }
DIGIT = {
  0x7f & ~D => 0,
  C | F => 1,
  0x7f & ~(B | F) => 2,
  0x7f & ~(B | E) => 3,
  B | C | D | F => 4,
  0x7f & ~(C | E) => 5,
  0x7f & ~C => 6,
  A | C | F => 7,
  0x7f => 8,
  0x7f & ~E => 9,
}.freeze

# Slower but does more validation of the input
# (raises if there are any non-digits, etc.)
def unscramble_strict((samples, outs))
  code1 = one(samples.select { |s| s.size == 2 })
  code7 = one(samples.select { |s| s.size == 3 })
  code4 = one(samples.select { |s| s.size == 4 })
  a = one(code7.chars - code1.chars)
  # most segments are unique in how many times they appear in the ten digits
  seg = samples.join.each_char.tally.to_h { |c, freq|
    [c, case freq
    when 4; E
    when 6; B
    when 7; code4.include?(c) ? D : G
    when 8; c == a ? A : C
    when 9; F
    else raise "bad freq #{samples} #{c} #{freq}"
    end]
  }.freeze
  raise "bad freq #{seg}" if seg.size != 7
  outs.reduce(0) { |acc, out| acc * 10 + DIGIT.fetch(out.each_char.sum(&seg)) }
end

# Faster because it does little work to distinguish between digits,
# but more likely to misinterpret garbage inputs as valid.
def unscramble_fast((samples, outs))
  code1 = one(samples.select { |s| s.size == 2 })
  code4 = one(samples.select { |s| s.size == 4 })
  cf = code1.chars
  bd = code4.chars - cf

  outs.reduce(0) { |acc, out| acc * 10 + case out.size
    when 2; 1
    when 3; 7
    when 4; 4
    when 5;
      oc = out.chars
      # 5 the only one that has both B and D (2 and 3 lack B)
      # 3 the only one that has both C and F (2 lacks F, 5 lacks C)
      # 2 the only one that has neither BD nor CF
      bd & oc == bd ? 5 : cf & oc == cf ? 3 : 2
    when 6;
      oc = out.chars
      # 0 lacks D, and we know BD
      # 6 lacks C, and we know CF
      # 9 lacks E
      bd & oc != bd ? 0 : cf & oc != cf ? 6 : 9
    when 7; 8
    else raise "bad #{out}"
    end
  }
end

def one(x)
  raise "bad #{x} should have size 1" if x.size != 1
  x[0]
end

displays = ARGF.map { |line|
  line.split(' | ', 2).map { |x| x.split.map(&:freeze).freeze }.freeze
}.freeze
easy = Array.new(8) { |i| [2, 3, 4, 7].include?(i) }.freeze
puts displays.sum { |_, outs| outs.count { |out| easy[out.size] }}
#puts displays.sum(&method(:unscramble_fast))
puts displays.sum(&method(:unscramble_strict))
