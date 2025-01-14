if {[file isdirectory work]} { vdel -all -lib work }

vlib work
vmap work work

vcom -work work -93 -explicit NOC/Hermes_package.vhd
vcom -work work -93 -explicit NOC/Hermes_buffer.vhd
vcom -work work -93 -explicit NOC/Hermes_switchcontrol.vhd
vcom -work work -93 -explicit NOC/Hermes_crossbar.vhd
vcom -work work -93 -explicit NOC/RouterCC.vhd
vcom -work work -93 -explicit NOC/request_record_cam.vhd
vcom -work work -93 -explicit NOC/requests_packaging.vhd
vcom -work work -93 -explicit NOC/wishbone_interface.vhd
vcom -work work -93 -explicit NOC/siphash/siphash_package.vhd
vcom -work work -93 -explicit NOC/siphash/sipround.vhd
vcom -work work -93 -explicit NOC/siphash/siphash.vhd
vcom -work work -93 -explicit NOC/network_interface.vhd
vcom -work work -93 -explicit Peripherals/wb_256x2_bytes_memory.vhd
vcom -work work -93 -explicit NOC/NOC.vhd
vcom -work work -93 -explicit topNoC.vhd

vsim -novopt -t 10ps work.topNoC

set StdArithNoWarnings 1
set StdVitalGlitchNoWarnings 1

do wave.do

run 6 us

wave zoom full

