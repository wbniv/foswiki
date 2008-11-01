set parametric
set isosamples 50,10
set hidden
set title "Interlocking Tori"
set key below
set urange [-pi:pi]
set vrange [-pi:pi]
set isosamples 50,20
set terminal png
splot cos(u)+.5*cos(u)*cos(v),sin(u)+.5*sin(u)*cos(v),.5*sin(v) with lines, 1+cos(u)+.5*cos(u)*cos(v),.5*sin(v),sin(u)+.5*sin(u)*cos(v) with lines