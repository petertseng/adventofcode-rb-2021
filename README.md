# adventofcode-rb-2021

[![Build Status](https://travis-ci.org/petertseng/adventofcode-rb-2021.svg?branch=master)](https://travis-ci.org/petertseng/adventofcode-rb-2021)

For the seventh year in a row, it's the time of the year to do [Advent of Code](http://adventofcode.com) again.

The solutions are written with the following goals, with the most important goal first:

1. **Speed**.
   Where possible, use efficient algorithms for the problem.
   Solutions that take more than a second to run are treated with high suspicion.
   This need not be overdone; micro-optimisation is not necessary.
2. **Readability**.
3. **Less is More**.
   Whenever possible, write less code.
   Especially prefer not to duplicate code.
   This helps keeps solutions readable too.

All solutions are written in Ruby.
Features from 3.0.x will be used, with no regard for compatibility with past versions.
`Enumerable#to_h` with block is anticipated to be the most likely reason for incompatibility (will make it incompatible with 2.5).

# Input

In general, all solutions can be invoked in both of the following ways:

* Without command-line arguments, takes input on standard input.
* With command-line arguments, reads input from the named files (- indicates standard input).

Some may additionally support other ways:

* None yet

# Highlights

Favourite problems:

* None yet.

Interesting approaches:

* None yet.

# Takeaways

* Day 04 (Giant Squid Bingo): Read too fast and skipped over the part where diagonals don't count.
  This was despite staring at the example where there was a diagonal line and the text said there are still no winners.
  Check examples and assumptions.
  Also wasted time manually typing out the indices of each row, column, and diagonal instead of using loops or something.
  Maybe don't wastefully manually type stuff.
* Day 09 (Smoke Basin): Oops, accidentally parsed an entire row as one huge number instead of each individual cell.
  Maybe try printing out the result of the parse to make sure you got it right!
* Day 11 (Dumbo Octopus): Didn't make the same parsing mistake this time!
  However, made mistakes by using `>= 9` instead of `> 9`, forgetting diagonals, and an off-by-one.
  Checking against the example is good!
  Caught the first two mistakes by checking against the example and would have caught the last one by checking against the example before submitting.
* Day 12 (Passage Pathing): Reached for the wrong tool at first - thought it'd be BFS, and was very confused at how to apply that to revisiting large rooms.
  Consider whether something is really the right tool for the job.
* Day 13 (Transparent Origami): Fast on part 1 by using an equation that would correctly deduplicate folded points, but would mangle coordinates (`(coord - fold).abs`).
  Should have slowed down and written down a few before/after values (7 maps to 3 after a fold on 5, 8 maps to 2, etc.) which would have easily gotten me the correct equations.

# Posting schedule and policy

Before I post my day N solution, the day N leaderboard **must** be full.
No exceptions.

Waiting any longer than that seems generally not useful since at that time discussion starts on [the subreddit](https://www.reddit.com/r/adventofcode) anyway.

Solutions posted will be **cleaned-up** versions of code I use to get leaderboard times (if I even succeed in getting them), rather than the exact code used.
This is because leaderboard-seeking code is written for programmer speed (whatever I can come up with in the heat of the moment).
This often produces code that does not meet any of the goals of this repository (seen in the introductory paragraph).

# Past solutions

The [index](https://github.com/petertseng/adventofcode-common/blob/master/index.md) lists all years/languages I've ever done (or will ever do).
