VERBOSE2 = ARGV.delete('-vv')
VERBOSE = VERBOSE2 || ARGV.delete('-v')

# Returns [version, value]
def packet(d, level = 0)
  int = ->sz { d.shift(sz).join.to_i(2) }
  raise 'no' if d.empty?
  pad = ' ' * level * 2

  ver = int[3]
  type = int[3]

  if type == 4
    val = []
    loop {
      last = d.shift
      val.concat(d.shift(4))
      break if last == 0
      raise "bad last #{last} not 0 or 1" if last != 1
    }
    val = val.join.to_i(2)
    puts "#{pad}literal ver=#{ver} val=#{val} (#{val.bit_length} bits)" if VERBOSE2
    return [ver, val]
  end

  length_type = d.shift

  subpackets = if length_type == 0
    sublen = int[15]
    puts "#{pad}operator ver=#{ver} len=#{sublen}" if VERBOSE2
    dsub = d.shift(sublen)
    subs = []
    subs << packet(dsub, level + 1) until dsub.empty?
    subs
  elsif length_type == 1
    num_subpackets = int[11]
    puts "#{pad}operator ver=#{ver} n=#{num_subpackets}" if VERBOSE2
    num_subpackets.times.map { packet(d, level + 1) }
  else raise "bad length type #{length_type}"
  end

  subvals = subpackets.map(&:last)
  binop = ->sym {
    raise "#{sym} only takes two" if subvals.size != 2
    v = subvals[0].send(sym, subvals[1]) ? 1 : 0
    puts "#{pad} #{subvals[0]} #{sym} #{subvals[1]} = #{v}" if VERBOSE
    v
  }
  op = ->(sym, &b) {
    v = b ? b[subvals] : subvals.send(sym)
    puts "#{pad}#{sym} #{subvals} = #{v}" if VERBOSE
    v
  }

  val = case type
  when 0; op[:sum]
  when 1; op[:product] { |vs| vs.reduce(1, :*) }
  when 2; op[:min]
  when 3; op[:max]
  when 5; binop[:>]
  when 6; binop[:<]
  when 7; binop[:==]
  else raise "bad type #{type}"
  end

  [ver + subpackets.sum(&:first), val]
end

input = ARGF.read.chomp
d = input.to_i(16).digits(2).reverse
(input.size * 4 - d.size).times { d.unshift(0) }
puts packet(d)
puts "unparsed #{d}" if VERBOSE2
raise "unparsed #{d}" unless d.all?(&:zero?)
