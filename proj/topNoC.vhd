library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.conv_std_logic_vector;
use work.HermesPackage.all;
use work.standards.all;

entity topNoC is
   generic(
      X_ROUTERS: integer := 3;
      Y_ROUTERS: integer := 3
   );
end;

architecture topNoC of topNoC is

   signal clock : std_logic_vector( (X_ROUTERS*Y_ROUTERS-1) downto 0) := (others=>'0');
   signal reset : std_logic;
   signal clock_rx, rx, credit_o: std_logic_vector( (X_ROUTERS*Y_ROUTERS-1) downto 0);
   signal clock_tx, tx, credit_i: std_logic_vector( (X_ROUTERS*Y_ROUTERS-1) downto 0);
   signal data_in, data_out : arrayNrot_regflit( (X_ROUTERS*Y_ROUTERS-1) downto 0 );

   constant NB_ROUTERS : integer :=  X_ROUTERS * Y_ROUTERS;

   --- geração manual dos pacotes
   signal address1, data1:  std_logic_vector(15 downto 0);
   signal ce1: std_logic;

   -- Requests route:  00 -> 10 -> 20 -> 21 -> 22
   -- Responses route: 22 -> 12 -> 02 -> 01 -> 00
   constant pck1 : service_request_packet := (
      x"C122", x"0003", service_request, x"0000", x"000A"
   );

   constant pck2 : service_request_packet := (
      x"C122", x"0003", service_request, x"0000", x"000B"
   );

   constant pck3 : service_request_write_packet := (
      x"C122", x"0009", service_request_write, x"0000", x"000A", x"0005",
      x"FF01", x"FF02", x"FF03", x"FF04", x"FF05"
   );

   constant pck4 : service_request_read_packet := (
      x"C122", x"0004", service_request_read, x"0000", x"000C", x"0005"
   );

   constant pck5 : service_request_read_packet := (
      x"C122", x"0004", service_request_read, x"0000", x"000B", x"0005"
   );

begin
   reset <= '1', '0' after 15 ns;


   clocks_router: for i in 0 to NB_ROUTERS-1 generate
      clock(i) <= not clock(i) after 10 ns;

      grounding: if i /= 0  generate
         clock_rx(i) <= '0';
         rx(i) <= '0';
      end generate;
   end generate clocks_router;


   noc1: Entity work.NOC
   generic map (
      X_ROUTERS => X_ROUTERS,
      Y_ROUTERS => Y_ROUTERS
   )
   port map (
      clock         => clock,
      reset         => reset,
      clock_rxLocal => clock_rx,
      rxLocal       => rx,
      data_inLocal  => data_in,
      credit_oLocal => credit_o,
      clock_txLocal => clock_tx,
      txLocal       => tx,
      data_outLocal => data_out,
      credit_iLocal => credit_i
   );

   clock_rx(0) <= clock(0);     -- clock to inject data - the same of the router


   -----   geração da dados   ------
   process(reset, clock(0))
   begin
      if reset = '1' then
         rx(0) <= '0';
      elsif clock(0)'event and clock(0) = '1' then
         if ce1 = '1' and address1 = x"FFFF" then
            rx(0) <= '1';
            data_in(0) <= data1;
         elsif credit_o(0) = '1' then -- important: flow control
            rx(0) <= '0';
         end if;
      end if;
   end process;

   address1 <= x"FFFF";   -- address generated by the processor
   credit_i(8) <= '1';
   credit_i(0) <= '1';

   process
      variable i : integer:= 0;
   begin
      ce1 <= '0';
      wait for 500 ns;     -- time between packets

      i := 0;
      while i < pck1'length loop
         if credit_o(N0000)='1' then
            data1 <= pck1(i);
            ce1  <= '1';
            wait for 20 ns;
            ce1  <= '0';
            wait for 20 ns;
            i := i + 1;
         else
            wait for 20 ns;
         end if;
      end loop;

      wait for 500 ns;
      i := 0;
      while i < pck2'length loop
         if credit_o(N0000)='1' then
            data1 <= pck2(i);
            ce1  <= '1';
            wait for 20 ns;
            ce1  <= '0';
            wait for 20 ns;
            i := i + 1;
         else
            wait for 20 ns;
         end if;
      end loop;

      wait for 500 ns;
      i := 0;
      while i < pck3'length loop
         if credit_o(N0000)='1' then
            data1 <= pck3(i);
            ce1  <= '1';
            wait for 20 ns;
            ce1  <= '0';
            wait for 20 ns;
            i := i + 1;
         else
            wait for 20 ns;
         end if;
      end loop;

      wait for 500 ns;
      i := 0;
      while i < pck4'length loop
         if credit_o(N0000)='1' then
            data1 <= pck4(i);
            ce1  <= '1';
            wait for 20 ns;
            ce1  <= '0';
            wait for 20 ns;
            i := i + 1;
         else
            wait for 20 ns;
         end if;
      end loop;

      wait for 500 ns;
      i := 0;
      while i < pck5'length loop
         if credit_o(N0000)='1' then
            data1 <= pck5(i);
            ce1  <= '1';
            wait for 20 ns;
            ce1  <= '0';
            wait for 20 ns;
            i := i + 1;
         else
            wait for 20 ns;
         end if;
      end loop;

      wait for 2000 ns;

   end process;

end topNoC;
