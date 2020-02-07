library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity wb_256x2_bytes_memory is
   generic(
      LENGTH: integer := 256
   );
   port(
      clock     : in  std_logic;
      reset     : in  std_logic;

      adr_i     : in  std_logic_vector(7 downto 0);
      dat_i     : in  std_logic_vector(15 downto 0);
      dat_o     : out std_logic_vector(15 downto 0);
      we_i      : in  std_logic;
      stb_i     : in  std_logic;
      ack_o     : out std_logic;
      cyc_i     : in  std_logic;
      stall_o   : out std_logic
   );
end;

architecture main of wb_256x2_bytes_memory is

type t_buffer is array (0 to LENGTH-1) of std_logic_vector(15 downto 0);
signal buff : t_buffer := (others => (others => '0'));
signal tmp_data : std_logic_vector(15 downto 0);
signal s_ack_write : std_logic;
signal s_ack_read : std_logic;
signal s_dat_o : std_logic_vector(15 downto 0);

begin

   dat_o <= s_dat_o when s_ack_read = '1' else
            (others => '0');

   ack_o <= '0' when stb_i = '0' or cyc_i = '0' else s_ack_write or s_ack_read;

   stall_o <= '0';

   process(reset, clock)
   begin
      if reset = '1' then
         s_ack_write <= '0';
         tmp_data <= (others => '0');
      elsif (rising_edge(clock)) then
         if stb_i = '1' and we_i = '1' and cyc_i = '1' then
            tmp_data <= dat_i;
            buff(to_integer(ieee.numeric_std.unsigned(adr_i))) <= tmp_data;
            s_ack_write <= '1';
         else
            s_ack_write <= '0';
         end if;
      end if;
   end process;

   process(reset, clock)
   begin
      if reset = '1' then
         s_ack_read <= '0';
         s_dat_o <= (others => '0');
      elsif (rising_edge(clock)) then
         if stb_i = '1' and cyc_i = '1' and we_i = '0' then
            --TODO: Verify if the adr_i is valid
            s_dat_o <= buff(to_integer(ieee.numeric_std.unsigned(adr_i)));
            s_ack_read <= '1';
         else
            s_ack_read <= '0';
         end if;
      end if;
   end process;

end architecture main;