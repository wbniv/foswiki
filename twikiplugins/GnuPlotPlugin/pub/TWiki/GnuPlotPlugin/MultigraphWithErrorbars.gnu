set title "MultigraphWithErrorbars"
set xlabel "X Axis Label"
set ylabel "Y Axis Label"
set term gif
set data style lp
set terminal png
plot [.8:4.2] "MultigraphWithErrorbarsData.data" using 1:2 t "Curve Title", "MultigraphWithErrorbarsData.data" using 1:2:3:4 notitle with errorbars ps 0, "MultigraphWithErrorbarsData.data" using 1:5 t "Other Curve", "MultigraphWithErrorbarsData.data" using 1:5:6:7 notitle with errorbars ps 0