OPEN_MATCHING_CLOSE = {
  ?) => ?(,
  ?] => ?[,
  ?} => ?{,
  ?> => ?<,
}.each_value(&:freeze).freeze
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

def completion(opens)
  opens.reverse_each.reduce(0) { |a, c| a * 5 + COMP_SCORE.fetch(c) }
end

err = ERR_SCORE.transform_values { 0 }
comp = []

verbose2 = ARGV.delete('-vv')
verbose = verbose2 || ARGV.delete('-v')

ARGF.each_with_index { |line, i|
  opens = []
  next unless line.chomp.each_char.with_index { |c, j|
    if COMP_SCORE.has_key?(c)
      opens << c
    elsif opens.pop != OPEN_MATCHING_CLOSE.fetch(c)
      puts "#{i}: \e[1;31mcorrupt\e[0m @ #{j} #{c} #{line[0...j]}\e[1;31m#{c}\e[0m#{line[(j + 1)..-1]}" if verbose2
      err[c] += 1
      break
    end
  }
  comp << score = completion(opens)
  puts "#{i}: \e[1;32mincomplete\e[0m #{opens.join} = #{score}" if verbose2
}

puts err if verbose
puts err.sum { |c, freq| ERR_SCORE.fetch(c) * freq }

raise "even-sized comp #{comp.size} #{comp}" if comp.size.even?
puts "#{comp.size / 2} of #{comp.sort}" if verbose
puts comp.sort[comp.size / 2]
