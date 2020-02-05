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
    type packet is array (0 to 16) of std_logic_vector(15 downto 0);
   constant pck1 : packet :=
   ( x"0022", x"000F", x"1001", x"2002", x"3003", x"4004", x"5005",
     x"6006", x"7007", x"8008", x"9009", x"A00A",
     x"B00B", x"C00C", x"D00D", x"E00E", x"F00F"
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


   -----   geração da dados - está muito ruim  ------
   process(reset, clock(0))
   begin
      if reset='1' then
         rx(0) <= '0';
      elsif clock(0)'event and clock(0)='1' then
         if ce1='1' and address1=x"FFFF" then
            rx(0) <= '1';
            data_in(0) <= data1;
         elsif credit_o(0)='1' then      -- important: flow control
            rx(0) <= '0';
         end if;
      end if;
   end process;

   address1 <= x"FFFF";   -- address generated by the processor
   credit_i(8) <= '1';    --- no tutorial eu não sinalizava que precisa deixar o receptor apto

   process
      variable i : integer:= 0;
   begin
      ce1 <= '0';
      wait for 400 ns;     -- time between packets

      i := 0;
      while i < 17 loop

         if credit_o(0)='1' then    -- important: flow control
            data1 <= pck1(i);       -- simulate a write( pck(i), address_noc)
            ce1  <= '1';
            wait for 20 ns;
            ce1  <= '0';
            wait for 20 ns;
            i := i + 1;
         else
            wait for 20 ns;
         end if;

      end loop;
   end process;

end topNoC;