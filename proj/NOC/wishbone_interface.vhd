--
-- Add description here
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity wishbone_interface is
   generic (
      ADDR_LENGTH: integer := 8;
      DATA_LENGTH: integer := 16
   );
   port(
      clock        : in std_logic;
      reset        : in std_logic;

      -- Control bus
      send_write    : in std_logic;
      send_read     : in std_logic;
      write_address : in std_logic_vector(ADDR_LENGTH-1 downto 0);
      read_address  : in std_logic_vector(ADDR_LENGTH-1 downto 0);
      write_data    : in std_logic_vector(DATA_LENGTH-1 downto 0);

      -- Protocol bus
      per_clock    : out std_logic;
      per_reset    : out std_logic;
      address      : out std_logic_vector(ADDR_LENGTH-1 downto 0);
      data_i       : in  std_logic_vector(DATA_LENGTH-1 downto 0);
      data_o       : out std_logic_vector(DATA_LENGTH-1 downto 0);
      write_en     : out std_logic;
      stb          : out std_logic;
      ack          : in  std_logic;
      cyc          : out std_logic;
      stall        : in  std_logic
   );
end;

architecture main of wishbone_interface is

type wishbone_fsm_state_t is (waiting, sending_write, sending_read, cooldown);
signal wb_fsm_state               : wishbone_fsm_state_t;
signal s_cyc                      : std_logic;
signal s_stb                      : std_logic;
signal s_data_o                   : std_logic_vector(DATA_LENGTH-1 downto 0);
signal s_address                  : std_logic_vector(ADDR_LENGTH-1 downto 0);

begin

   wb_fsm_state <= waiting when reset = '1' else
                              sending_write when wb_fsm_state = waiting and send_write = '1' else
                              sending_read when wb_fsm_state = waiting and send_read = '1' else
                              cooldown when wb_fsm_state = sending_write and send_write = '0' and ack = '1' else
                              cooldown when wb_fsm_state = sending_read and send_read = '0' and ack = '1' else
                              waiting when wb_fsm_state = cooldown and s_cyc = '0' and s_stb = '0' else
                              wb_fsm_state;

   wb_fsm: process(reset, clock)
   begin
      if rising_edge(clock) then
         case wb_fsm_state is
            when waiting =>
               s_data_o <= (others => '0');
               write_en <= '0';
               s_stb <= '0';
               s_cyc <= '0';
            when sending_write =>
               if send_write = '1' then
                  s_cyc <= '1';
                  s_stb <= '1';
                  write_en <= '1';
                  s_data_o <= write_data;
               end if;
            when cooldown =>
               s_cyc <= '0';
               s_stb <= '0';
               write_en <= '0';
            when sending_read =>
               if send_read = '1' then
                  s_cyc <= '1';
                  s_stb <= '1';
                  write_en <= '0';
               end if;
         end case;
      end if;
   end process wb_fsm;

   data_o <= s_data_o when wb_fsm_state = sending_write else (others => '0');

   cyc <= s_cyc;
   stb <= s_stb;

   s_address <= (others => '0') when reset = '1'else
               write_address when wb_fsm_state = sending_write and send_write = '1' else
               read_address when wb_fsm_state = sending_read and send_read = '1' else
               s_address;

   address <= s_address;

   per_clock <= clock;
   per_reset <= reset;

end architecture main;