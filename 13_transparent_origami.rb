verbose = ARGV.delete('-v')

fold = ->(v, along) { v <= along ? v : 2 * along - v }

dot = ARGF.take_while { |l| !l.chomp.empty? }.to_h { |line|
  [line.split(?,, 2).map(&method(:Integer)).freeze, true]
}

ARGF.each_with_index { |line, i|
  raise "#{line} not a fold" unless line.start_with?('fold along')

  fold_line = line.split(' ', 3)[2]
  dim, along = fold_line.split(?=, 2)
  along = Integer(along)
  check = verbose ? ->pos { puts "fold #{dim} #{along} #{dot.keys.map { |d| d[pos] }.minmax}" } : [nil, nil]
  case dim
  when ?x; check[0]; dot.transform_keys! { |x, y| [fold[x, along], y].freeze }
  when ?y; check[1]; dot.transform_keys! { |x, y| [x, fold[y, along]].freeze }
  else raise "bad dim #{dim} #{line}"
  end

  puts dot.size if i == 0
}

xmin, xmax = dot.each_key.map(&:first).minmax
ymin, ymax = dot.each_key.map(&:last).minmax
(ymin..ymax).each { |y|
  (xmin..xmax).each { |x|
    print dot.has_key?([x, y]) ? ?# : ' '
  }
  puts
}
