if {[file isdirectory work]} { vdel -all -lib work }

vlib work
vmap work work

vcom -work work -93 -explicit siphash_package.vhd
vcom -work work -93 -explicit sipround.vhd
vcom -work work -93 -explicit siphash.vhd
vcom -work work -93 -explicit tb_siphash.vhd

vsim -novopt -t 10ps work.tb_siphash

set StdArithNoWarnings 1
set StdVitalGlitchNoWarnings 1

do wave.do 

run 7 us

wave zoom full

