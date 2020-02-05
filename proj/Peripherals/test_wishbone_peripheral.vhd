library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use work.HermesPackage.all;

entity test_wishbone_peripheral is
   port(
      clock     : in  std_logic;
      reset     : in  std_logic;

      adr_i     : in  std_logic_vector(7 downto 0);
      dat_i     : in  std_logic_vector(TAM_FLIT-1 downto 0);
      dat_o     : out std_logic_vector(TAM_FLIT-1 downto 0);
      we_i      : in  std_logic;
      stb_i     : in  std_logic;
      ack_o     : out std_logic;
      cyc_i     : in  std_logic
   );
end;

architecture test of test_wishbone_peripheral is

type t_buffer_out is array (0 to 254) of std_logic_vector(TAM_FLIT-1 downto 0);
type t_buffer_in is array (0 to 1) of std_logic_vector(TAM_FLIT-1 downto 0);

signal buffer_out : t_buffer_out := (others => (others => '0'));
signal buffer_in : t_buffer_in := (others => (others => '0'));
signal received_counter : integer range 0 to 2 := 0;
signal buffer_avaliable : std_logic;
signal data_received : std_logic;
signal address : std_logic_vector(7 downto 0);
signal start_operation : std_logic;
signal request_received : std_logic;

begin

   process(reset, clock)
   begin
      if (rising_edge(clock)) then
         if reset = '1' then
               dat_o <= (others => '0');
               received_counter <= 0;
               buffer_avaliable <= '1';
               data_received <= '0';
               start_operation <= '0';
               request_received <= '0';
         else

               if stb_i = '1' and cyc_i = '1' then
                  start_operation <= '1';
               end if;

               -- handle write requests
               if we_i = '1' and start_operation = '1' and buffer_avaliable = '1' then
                  address <= adr_i;

                  if received_counter = 2 then -- receive only two numbers
                     buffer_avaliable <= '0';
                     data_received <= '1';
                  else
                     received_counter <= received_counter + 1;
                     buffer_in(received_counter) <= dat_i;
                  end if;
               end if;

               -- write to buffer
               if data_received = '1' then
                  start_operation <= '0';
                  buffer_out(to_integer(ieee.numeric_std.unsigned(address))) <= buffer_in(0) + buffer_in(1);
               end if;

               -- handle read requests
               if we_i = '0' and start_operation = '1' then
                  address <= adr_i;
                  request_received <= '1';
                  dat_o <= buffer_out(to_integer(ieee.numeric_std.unsigned(address)));
                  start_operation <= '0';
               end if;

               if start_operation = '0' then
                  request_received <= '0';
                  data_received <= '0';
               end if;

         end if;
      end if;
   end process;

   ack_o <= '1' when stb_i = '1' and cyc_i = '1' else
            '1' when we_i = '1' and buffer_avaliable = '1' else
            '1' when we_i = '0' and request_received = '1' else
            '0';

end architecture;