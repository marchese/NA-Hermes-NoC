add wave -position end -group NetworkInterface sim:/topnoc/noc1/network_interface/*
add wave -position end -group Peripheral sim:/topnoc/noc1/wishbone_peripheral/*

add wave -divider {data source}
add wave -format Logic /topnoc/ce1
add wave -format Literal -radix hexadecimal /topnoc/data1

add wave -divider {router 00 local port in}
add wave -format Logic /topnoc/noc1/clock(0)
add wave -format Logic /topnoc/noc1/rx(0)(4)
add wave -format Logic /topnoc/noc1/credit_o(0)(4)
add wave -format Literal -radix hexadecimal /topnoc/noc1/data_in(0)(4)

add wave -divider {router 00 east port out}
add wave -format Logic /topnoc/noc1/tx(0)(0)
add wave -format Logic /topnoc/noc1/credit_i(0)(0)
add wave -format Literal -radix hexadecimal /topnoc/noc1/data_out(0)(0)


add wave -divider {router 10 east port out}
add wave -format Logic /topnoc/noc1/tx(1)(0)
add wave -format Logic /topnoc/noc1/credit_i(1)(0)
add wave -format Literal -radix hexadecimal /topnoc/noc1/data_out(1)(0)


add wave -divider {router 20 north port out}
add wave -format Logic /topnoc/noc1/tx(2)(2)
add wave -format Logic /topnoc/noc1/credit_i(2)(2)
add wave -format Literal -radix hexadecimal /topnoc/noc1/data_out(2)(2)


add wave -divider {router 21 north port out}
add wave -format Logic /topnoc/noc1/tx(5)(2)
add wave -format Logic /topnoc/noc1/credit_i(5)(2)
add wave -format Literal -radix hexadecimal /topnoc/noc1/data_out(5)(2)


add wave -divider {router 22 north port out}
add wave -format Logic /topnoc/noc1/tx(8)(2)
add wave -format Logic /topnoc/noc1/credit_i(8)(2)
add wave -format Literal -radix hexadecimal /topnoc/noc1/data_out(8)(2)


add wave -divider {router 22 local port out}
add wave -format Logic /topnoc/noc1/tx(8)(4)
add wave -format Logic /topnoc/noc1/credit_i(8)(4)
add wave -format Literal -radix hexadecimal /topnoc/noc1/data_out(8)(4)


add wave -divider {router 22 north port in}
add wave -format Logic /topnoc/noc1/rx(8)(2)
add wave -format Logic /topnoc/noc1/credit_o(8)(2)
add wave -format Literal -radix hexadecimal /topnoc/noc1/data_in(8)(2)


add wave -divider {router 22 west port out}
add wave -format Logic /topnoc/noc1/tx(8)(1)
add wave -format Logic /topnoc/noc1/credit_i(8)(1)
add wave -format Literal -radix hexadecimal /topnoc/noc1/data_out(8)(1)


add wave -divider {router 12 west port out}
add wave -format Logic /topnoc/noc1/tx(7)(1)
add wave -format Logic /topnoc/noc1/credit_i(7)(1)
add wave -format Literal -radix hexadecimal /topnoc/noc1/data_out(7)(1)


add wave -divider {router 02 west port out}
add wave -format Logic /topnoc/noc1/tx(6)(3)
add wave -format Logic /topnoc/noc1/credit_i(6)(3)
add wave -format Literal -radix hexadecimal /topnoc/noc1/data_out(6)(3)


add wave -divider {router 01 east port out}
add wave -format Logic /topnoc/noc1/tx(3)(3)
add wave -format Logic /topnoc/noc1/credit_i(3)(3)
add wave -format Literal -radix hexadecimal /topnoc/noc1/data_out(3)(3)


add wave -divider {router 00 north port in}
add wave -format Logic /topnoc/noc1/rx(0)(2)
add wave -format Logic /topnoc/noc1/credit_o(0)(2)
add wave -format Logic /topnoc/noc1/credit_i(0)(2)
add wave -format Literal -radix hexadecimal /topnoc/noc1/data_in(0)(2)


add wave -divider {router 00 local port in}
add wave -format Logic /topnoc/noc1/rx(0)(4)
add wave -format Logic /topnoc/noc1/credit_o(0)(4)
add wave -format Logic /topnoc/noc1/tx(0)(4)
add wave -format Logic /topnoc/noc1/credit_i(0)(4)
add wave -format Literal -radix hexadecimal /topnoc/noc1/data_in(0)(4)