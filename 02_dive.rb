x = 0
y = 0
a = 0

verbose = ARGV.delete('-v')

ARGF.each_line { |l|
  dir, i = l.split(' ', 2)
  i = Integer(i)

  case dir
  when 'forward'
    x += i
    y += i * a
  when 'down'
    a += i
  when 'up'
    a -= i
  else raise "bad #{l}"
  end
}

puts({x: x, y: y, a: a}) if verbose
puts x * a
puts x * y
