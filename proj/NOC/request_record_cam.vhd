library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use work.HermesPackage.all;

-- Request Record CAM (RRCAM) is a Dual-Port Content Addressable Memory (CAM)
-- that stores the request of the network interface
entity request_record_cam is
   port (
      addra: in std_logic_vector(7 downto 0);
      addrb: in std_logic_vector(7 downto 0);
      clka: in std_logic;
      clkb: in std_logic;
      dina: in NI_SERVICE_REQUEST;
      doutb: out NI_SERVICE_REQUEST;
      enb: in std_logic;
      wea: in std_logic
   );
end request_record_cam;

architecture request_cam_256 of request_record_cam is

type SIMULATION_MEM_TYPE is array (0 to 255) of NI_SERVICE_REQUEST;
signal mem : SIMULATION_MEM_TYPE;

begin

process (clka)
begin
   if (rising_edge(clka)) then
      if wea = '1' then
         mem(to_integer(ieee.NUMERIC_STD.UNSIGNED(addra))) <= dina;
      end if;
   end if;
end process;

process (clkb)
begin
   if (rising_edge(clkb)) then
      if enb = '1' then
         doutb <= mem(to_integer(ieee.NUMERIC_STD.UNSIGNED(addrb)));
      end if;
   end if;
end process;

end request_cam_256;