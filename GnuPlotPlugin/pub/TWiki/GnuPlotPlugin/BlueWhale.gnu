set parametric
set hidden3d
set nokey
set xrange [0:8]
set yrange [-4:4]
set zrange [-2:2]
set data style line
set title "Blue Whale"
set terminal png
splot "whale.dat"
