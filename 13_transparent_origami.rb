dot = {}
folded = false

verbose = ARGV.delete('-v')

fold = ->(v, along) { v <= along ? v : 2 * along - v }

ARGF.each_line(chomp: true) { |line|
  if line.include?(?,)
    raise "can't add points after folded: #{line}" if folded
    dot[line.split(?,, 2).map(&method(:Integer)).freeze] = true
  elsif line.start_with?('fold along')
    fold_line = line.split(' ', 3)[2]
    dim, along = fold_line.split(?=, 2)
    along = Integer(along)
    check = verbose ? ->pos { puts "fold #{dim} #{along} #{dot.keys.map { |d| d[pos] }.minmax}" } : [nil, nil]
    case dim
    when ?x; check[0]; dot.transform_keys! { |x, y| [fold[x, along], y].freeze }
    when ?y; check[1]; dot.transform_keys! { |x, y| [x, fold[y, along]].freeze }
    else raise "bad dim #{dim} #{line}"
    end
    unless folded
      folded = true
      puts dot.size
    end
  elsif !line.strip.empty?
    raise "unknown #{line}"
  end
}

xmin, xmax = dot.each_key.map(&:first).minmax
ymin, ymax = dot.each_key.map(&:last).minmax
(ymin..ymax).each { |y|
  (xmin..xmax).each { |x|
    print dot.has_key?([x, y]) ? ?# : ' '
  }
  puts
}
