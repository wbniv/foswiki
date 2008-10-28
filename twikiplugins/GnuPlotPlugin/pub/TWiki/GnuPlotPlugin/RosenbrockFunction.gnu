set logscale z 10
set view 20, 340, 1, 1
set isosamples 60, 60
set hidden3d offset 1 trianglepattern 3 undefined 1 altdiagonal bentover
set style data lines
set ticslevel 0
set title "Rosenbrock Function" 0.000000,0.000000  font ""
set xlabel "x" -5.000000,-2.000000  font ""
set xrange [ * : * ] noreverse nowriteback  # (currently [0.00000:15.0000] )
set ylabel "y" 4.000000,-1.000000  font ""
set yrange [ * : * ] noreverse nowriteback  # (currently [0.00000:15.0000] )
set zlabel "Z axis" 0.000000,0.000000  font ""
set zrange [ * : * ] noreverse nowriteback  # (currently [-1.20000:1.20000] )
set terminal png size 350,280
splot [-1.5:1.5] [-0.5:1.5] (1-x)**2 + 100*(y - x**2)**2
