if {[file isdirectory work]} { vdel -all -lib work }

vlib work
vmap work work

#sccom -g SC_NoC/SC_InputModule.cpp
#sccom -g SC_NoC/SC_OutputModule.cpp
#sccom -g SC_NoC/SC_OutputModuleRouter.cpp
#sccom -link

vcom -work work -93 -explicit NOC/Hermes_package.vhd
vcom -work work -93 -explicit NOC/Hermes_buffer.vhd
vcom -work work -93 -explicit NOC/Hermes_switchcontrol.vhd
vcom -work work -93 -explicit NOC/Hermes_crossbar_BL.vhd
vcom -work work -93 -explicit NOC/Hermes_crossbar_BC.vhd
vcom -work work -93 -explicit NOC/Hermes_crossbar_BR.vhd
vcom -work work -93 -explicit NOC/Hermes_crossbar_CL.vhd
vcom -work work -93 -explicit NOC/Hermes_crossbar_CC.vhd
vcom -work work -93 -explicit NOC/Hermes_crossbar_CR.vhd
vcom -work work -93 -explicit NOC/Hermes_crossbar_TL.vhd
vcom -work work -93 -explicit NOC/Hermes_crossbar_TC.vhd
vcom -work work -93 -explicit NOC/Hermes_crossbar_TR.vhd
vcom -work work -93 -explicit NOC/RouterBL.vhd
vcom -work work -93 -explicit NOC/RouterBC.vhd
vcom -work work -93 -explicit NOC/RouterBR.vhd
vcom -work work -93 -explicit NOC/RouterCL.vhd
vcom -work work -93 -explicit NOC/RouterCC.vhd
vcom -work work -93 -explicit NOC/RouterCR.vhd
vcom -work work -93 -explicit NOC/RouterTL.vhd
vcom -work work -93 -explicit NOC/RouterTC.vhd
vcom -work work -93 -explicit NOC/RouterTR.vhd
vcom -work work -93 -explicit test_wishbone_peripheral.vhd
vcom -work work -93 -explicit network_interface.vhd
#vcom -work work -93 -explicit test_peripheral.vhd
vcom -work work -93 -explicit NOC/NOC.vhd
vcom -work work -93 -explicit topNoC.vhd

vsim -novopt -t 10ps work.topNoC

set StdArithNoWarnings 1
set StdVitalGlitchNoWarnings 1

do wave.do

run 4 us

#quit -sim
#quit -f

