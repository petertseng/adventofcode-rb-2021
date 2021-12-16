# parses parenthesised expressions into a day 16 input
# prefix an op with ! to force length type ID 0,
# prefix an op with @ to force length type ID 1,
# otherwise it's randomly chosen.
# example:
# (* (max 4 1 9) (min 7 2 8) (+ (* 3 2) 4) (+ 5 6 7 8))
expr = (ARGV.size == 1 && File.exist?(ARGV[0])) ? ARGF.read : ARGV.join(' ')

def tok(s)
  i1 = s.index(' ')
  i2 = s.index(?))
  s.shift([i1, i2].compact.min).join.tap { s.shift while s[0] == ' ' }
end

def parse_paren(s, level = 0)
  open = s.shift
  raise "#{open} should be (" if open != ?(
  op = tok(s)

  v = [op.freeze]

  loop {
    #puts "level #{level}: so far #{v}, remain #{s}"
    if s[0] == ?)
      s.shift
      s.shift while s[0] == ' '
      return v.freeze
    elsif s[0] == ?(
      v << parse_paren(s, level + 1)
    else
      v << Integer(tok(s))
    end
  }
end

def encode_packet(thing)
  # Ver
  encoded = Array.new(3) { rand(0..1) }

  if thing.is_a?(Integer)
    encoded.concat(encode_literal(thing))
    return encoded
  end

  raise "what is #{thing}?" unless thing.is_a?(Array)

  length_type, op = if thing[0].start_with?(?!)
    [0, thing[0][1..]]
  elsif thing[0].start_with?(?@)
    [1, thing[0][1..]]
  else
    [rand(0..1), thing[0]]
  end

  type = case op
  when ?+; [0, 0, 0]
  when ?*; [0, 0, 1]
  when 'min'; [0, 1, 0]
  when 'max'; [0, 1, 1]
  when ?>; [1, 0, 1]
  when ?<; [1, 1, 0]
  when '==', ?=; [1, 1, 1]
  else raise "bad op #{op}"
  end
  raise "only two ops allowed" if type[0] == 1 && thing.size != 3

  encoded.concat(type)
  encoded << length_type
  children = thing[1..].map { |t| encode_packet(t) }
  case length_type
  when 0; encoded.concat(encode_fixnum(children.sum(&:size), 15))
  when 1; encoded.concat(encode_fixnum(children.size, 11))
  else raise "bad length type #{length_type}"
  end
  encoded.concat(children.flatten)
  encoded
end

def encode_fixnum(n, sz)
  bits = n.digits(2).reverse
  raise "#{n} too big for #{sz} bits!!!" if bits.size > sz
  bits.unshift(0) until bits.size == sz
  bits
end

# note this includes the type bits
def encode_literal(n)
  bits = n.digits(2).reverse
  bits.unshift(0) until bits.size > 0 && bits.size % 4 == 0
  *init, last = bits.each_slice(4).to_a
  [1, 0, 0] + init.flat_map { |g| [1] + g } + [0] + last
end

def hex(bits)
  bits << 0 until bits.size % 4 == 0
  bits.each_slice(4).map { |n| n.join.to_i(2).to_s(16).upcase }.join
end

c = expr.chars
se = parse_paren(c)

#puts "parsed: #{e}"
raise "unparsed #{c}" unless c.empty?

enc = encode_packet(se)
puts hex(enc)
