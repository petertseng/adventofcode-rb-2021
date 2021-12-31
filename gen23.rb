require 'set'

letters = %w(A A B B C C D D)

a = Set.new(letters.permutation)
a.each { |perm|
  File.open("all23/#{perm.join}.in", ?w) { |f|
    f.puts '#############'
    f.puts '#...........#'
    f.puts "####{perm[0]}##{perm[1]}##{perm[2]}##{perm[3]}###"
    f.puts "  ##{perm[4]}##{perm[5]}##{perm[6]}##{perm[7]}#"
    f.puts '  #########'
  }
}
