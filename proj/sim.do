if {[file isdirectory work]} { vdel -all -lib work }

vlib work
vmap work work

vcom -work work -93 -explicit NOC/Hermes_package.vhd
vcom -work work -93 -explicit NOC/Hermes_buffer.vhd
vcom -work work -93 -explicit NOC/Hermes_switchcontrol.vhd
vcom -work work -93 -explicit NOC/Hermes_crossbar.vhd
vcom -work work -93 -explicit NOC/RouterCC.vhd
vcom -work work -93 -explicit NOC/NOC.vhd
vcom -work work -93 -explicit topNoC.vhd

vsim -t 10ps work.topNoC

set StdArithNoWarnings 1
set StdVitalGlitchNoWarnings 1

do wave.do 

run 2 us

