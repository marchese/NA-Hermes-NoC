add wave -divider {FONTE DOS DADOS}
add wave -format Logic /topnoc/ce1
add wave -format Literal -radix hexadecimal /topnoc/data1

add wave -divider {roteador 00 PORTA LOCAL}
add wave -format Logic /topnoc/noc1/clock(0)
add wave -format Logic /topnoc/noc1/rx(0)(4)
add wave -format Logic /topnoc/noc1/credit_o(0)(4)
add wave -format Literal -radix hexadecimal /topnoc/noc1/data_in(0)(4)

add wave -divider {roteador 00 PORTA LESTE}
add wave -format Logic /topnoc/noc1/tx(0)(0)
add wave -format Logic /topnoc/noc1/credit_i(0)(0)
add wave -format Literal -radix hexadecimal /topnoc/noc1/data_out(0)(0)


add wave -divider {roteador 10 PORTA LESTE}
add wave -format Logic /topnoc/noc1/tx(1)(0)
add wave -format Logic /topnoc/noc1/credit_i(1)(0)
add wave -format Literal -radix hexadecimal /topnoc/noc1/data_out(1)(0)


add wave -divider {roteador 20 PORTA NORTE}
add wave -format Logic /topnoc/noc1/tx(2)(2)
add wave -format Logic /topnoc/noc1/credit_i(2)(2)
add wave -format Literal -radix hexadecimal /topnoc/noc1/data_out(2)(2)


add wave -divider {roteador 21 PORTA NORTE}
add wave -format Logic /topnoc/noc1/tx(5)(2)
add wave -format Logic /topnoc/noc1/credit_i(5)(2)
add wave -format Literal -radix hexadecimal /topnoc/noc1/data_out(5)(2)

 
add wave -divider {roteador 22 PORTA LOCAL}
add wave -format Logic /topnoc/noc1/tx(8)(4)
add wave -format Logic /topnoc/noc1/credit_i(8)(4)
add wave -format Literal -radix hexadecimal /topnoc/noc1/data_out(8)(4)
