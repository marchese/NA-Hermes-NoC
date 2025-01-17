------------------------------------------------------------------------------------------------
--
--  Brief description:  Functions and constants for NoC generation.
--
------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use work.HermesPackage.all;

package standards is

   --------------------------------------------------------------------------------
   -- Router position constants
   --------------------------------------------------------------------------------
   constant BL: integer := 0;
   constant BC: integer := 1;
   constant BR: integer := 2;
   constant CL: integer := 3;
   constant CC: integer := 4;
   constant CRX: integer := 5;
   constant TL: integer := 6;
   constant TC: integer := 7;
   constant TR: integer := 8;

   function RouterPosition(router, X_ROUTERS, Y_ROUTERS: integer) return integer;
   function RouterAddress(router, X_ROUTERS: integer)  return std_logic_vector;

   type arrayNrot_regflit is array (natural range <>) of regflit;

end standards;

package body standards is

   -- Returns the router position in the mesh
   -- BR: Botton Right
   -- BL: Botton Left
   -- TR: Top Right
   -- TL: Top Left
   -- CRX: Center Right
   -- CL: Center Left
   -- CC: Center
   -- 4x4 positions exemple
   --              TL TC TC TR
   --              CL CC CC CRX
   --              CL CC CC CRX
   --              BL BC BC BR
   function RouterPosition(router, X_ROUTERS, Y_ROUTERS: integer) return integer is
      variable pos: integer range 0 to TR;
      variable line, column: integer;
   begin

      column := router mod X_ROUTERS;

      if router >= (X_ROUTERS*Y_ROUTERS)-X_ROUTERS then --TOP ---------
         if column = X_ROUTERS-1 then    --RIGHT
            pos := TR;
         elsif column = 0 then          --LEFT
            pos := TL;
         else                           --CENTER_X
            pos := TC;
         end if;
      elsif router < X_ROUTERS then          --BOTTOM--------------
         if column = X_ROUTERS-1 then   --RIGHT
            pos := BR;
         elsif column = 0 then          --LEFT
            pos := BL;
         else                           --CENTER_X
            pos := BC;
         end if;
      else                                  --CENTER_Y-----------
         if column = X_ROUTERS-1 then  --RIGHT
            pos := CRX;
         elsif column = 0 then         --LEFT
            pos := CL;
         else                          --CENTER_X
            pos := CC;
         end if;
      end if;

      --report "POS "  & integer'image(pos) & "  " & integer'image(router)  & "  " &  integer'image(X_ROUTERS) & "  " & integer'image(Y_ROUTERS);

      return pos;

   end RouterPosition;


   function RouterAddress(router, X_ROUTERS: integer) return std_logic_vector is
      variable pos_x, pos_y   : regquartoflit;
      variable addr           : regmetadeflit;
      variable aux            : integer;
   begin
      aux := (router/X_ROUTERS);
      pos_x := conv_std_logic_vector((router mod X_ROUTERS),QUARTOFLIT);
      pos_y := conv_std_logic_vector(aux,QUARTOFLIT);

      addr := pos_x & pos_y;
      return addr;
   end RouterAddress;

end standards;


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use work.HermesPackage.all;
use work.standards.all;


--
-- THE EXTERNAL INTERFACE OF THE NOC ARE THE LOCAL PORTS OF ALL ROUTERS
--
entity NOC is
   generic(
      X_ROUTERS: integer := 4;
      Y_ROUTERS: integer := 4
   );
   port(
      clock         : in  std_logic_vector( (X_ROUTERS*Y_ROUTERS-1) downto 0);
      reset         : in  std_logic;

      clock_rxLocal : in  std_logic_vector( (X_ROUTERS*Y_ROUTERS-1) downto 0);
      rxLocal       : in  std_logic_vector( (X_ROUTERS*Y_ROUTERS-1) downto 0);
      data_inLocal  : in  arrayNrot_regflit( (X_ROUTERS*Y_ROUTERS-1) downto 0 );
      credit_oLocal : out std_logic_vector( (X_ROUTERS*Y_ROUTERS-1) downto 0);

      clock_txLocal : out std_logic_vector( (X_ROUTERS*Y_ROUTERS-1) downto 0);
      txLocal       : out std_logic_vector( (X_ROUTERS*Y_ROUTERS-1) downto 0);
      data_outLocal : out arrayNrot_regflit( (X_ROUTERS*Y_ROUTERS-1) downto 0 );
      credit_iLocal : in  std_logic_vector( (X_ROUTERS*Y_ROUTERS-1) downto 0)
   );
end NOC;

architecture NOC of NOC is

    constant NB_ROUTERS : integer :=  X_ROUTERS * Y_ROUTERS;

    -- array e sinais para controle - 5 fios de controle por roteador N/S/W/E/L
   type control_array is array (NB_ROUTERS-1 downto 0) of std_logic_vector(4 downto 0);
   signal tx, rx, clock_rx, clock_tx, credit_i, credit_o : control_array;

    -- barramentos de dados - number of ports of the router - 5 - N/S/W/E/L
   type data_array is array (NB_ROUTERS-1 downto 0) of arrayNport_regflit;
   signal data_in, data_out : data_array;

   signal address_router : regmetadeflit;

   type router_position is array (NB_ROUTERS-1 downto 0) of integer range 0 to TR;

   signal wb_clock    : std_logic;
   signal wb_reset    : std_logic;
   signal wb_address  : std_logic_vector(7 downto 0);
   signal wb_data_i   : std_logic_vector(TAM_FLIT-1 downto 0);
   signal wb_data_o   : std_logic_vector(TAM_FLIT-1 downto 0);
   signal wb_write_en : std_logic;
   signal wb_stb      : std_logic;
   signal wb_ack      : std_logic;
   signal wb_cyc      : std_logic;
   signal wb_stall    : std_logic;

begin


   noc: for i in 0 to NB_ROUTERS-1 generate

      router: entity work.RouterCC
      generic map( address => RouterAddress(i,X_ROUTERS) )
      port map(
         clock    => clock(i),
         reset    => reset,
         clock_rx => clock_rx(i),
         rx       => rx(i),
         data_in  => data_in(i),
         credit_o => credit_o(i),
         clock_tx => clock_tx(i),
         tx       => tx(i),
         data_out => data_out(i),
         credit_i => credit_i(i)
      );

      ------------------------------------------------------------------------------
      --- LOCAL PORT CONNECTIONS ----------------------------------------------------
      ------------------------------------------------------------------------------
      clock_rx(i)(LOCAL)       <= clock_rxLocal(i);
      rx(i)(LOCAL)             <= rxLocal(i);
      data_in(i)(LOCAL)        <= data_inLocal(i);
      credit_oLocal(i)         <= credit_o(i)(LOCAL);

      clock_txLocal(i)         <= clock_tx(i)(LOCAL);
      txLocal(i)               <= tx(i)(LOCAL) ;
      data_outLocal(i)         <= data_out(i)(LOCAL);
      credit_i(i)(LOCAL)       <= credit_iLocal(i);


      ------------------------------------------------------------------------------
      --- EAST PORT CONNECTIONS ----------------------------------------------------
      ------------------------------------------------------------------------------
      east_grounding: if routerPosition(i,X_ROUTERS,Y_ROUTERS)=BR or routerPosition(i,X_ROUTERS,Y_ROUTERS)=CRX or routerPosition(i,X_ROUTERS,Y_ROUTERS)=TR generate
         rx(i)(EAST)             <= '0';
         clock_rx(i)(EAST)       <= '0';
         credit_i(i)(EAST)       <= '0';
         data_in(i)(EAST)        <= (others => '0');
      end generate;

      east_connection: if routerPosition(i,X_ROUTERS,Y_ROUTERS)=BL or routerPosition(i,X_ROUTERS,Y_ROUTERS)=CL or routerPosition(i,X_ROUTERS,Y_ROUTERS)=TL  or routerPosition(i,X_ROUTERS,Y_ROUTERS)=BC or routerPosition(i,X_ROUTERS,Y_ROUTERS)= TC or routerPosition(i,X_ROUTERS,Y_ROUTERS)= CC generate
         rx(i)(EAST)             <= tx(i+1)(WEST);
         clock_rx(i)(EAST)       <= clock_tx(i+1)(WEST);
         credit_i(i)(EAST)       <= credit_o(i+1)(WEST);
         data_in(i)(EAST)        <= data_out(i+1)(WEST);
      end generate;

      ------------------------------------------------------------------------------
      --- WEST PORT CONNECTIONS ----------------------------------------------------
      ------------------------------------------------------------------------------
      west_grounding: if routerPosition(i,X_ROUTERS,Y_ROUTERS)=BL or routerPosition(i,X_ROUTERS,Y_ROUTERS)=CL or routerPosition(i,X_ROUTERS,Y_ROUTERS)=TL generate
         rx(i)(WEST)             <= '0';
         clock_rx(i)(WEST)       <= '0';
         credit_i(i)(WEST)       <= '0';
         data_in(i)(WEST)        <= (others => '0');
      end generate;

      west_connection: if (routerPosition(i,X_ROUTERS,Y_ROUTERS)=BR or routerPosition(i,X_ROUTERS,Y_ROUTERS)=CRX or routerPosition(i,X_ROUTERS,Y_ROUTERS)=TR or  routerPosition(i,X_ROUTERS,Y_ROUTERS)=BC or routerPosition(i,X_ROUTERS,Y_ROUTERS)= TC or routerPosition(i,X_ROUTERS,Y_ROUTERS)=CC) generate
         rx(i)(WEST)             <= tx(i-1)(EAST);
         clock_rx(i)(WEST)       <= clock_tx(i-1)(EAST);
         credit_i(i)(WEST)       <= credit_o(i-1)(EAST);
         data_in(i)(WEST)        <= data_out(i-1)(EAST);
      end generate;

      -------------------------------------------------------------------------------
      --- NORTH PORT CONNECTIONS ----------------------------------------------------
      -------------------------------------------------------------------------------
      -- TR router is excluded from the grounding logic because it is connected to a
      -- peripheral. See the TR PERIPHERAL section in this file.
      north_grounding: if routerPosition(i,X_ROUTERS,Y_ROUTERS)=TL or routerPosition(i,X_ROUTERS,Y_ROUTERS)=TC generate
         rx(i)(NORTH)            <= '0';
         clock_rx(i)(NORTH)      <= '0';
         credit_i(i)(NORTH)      <= '0';
         data_in(i)(NORTH)       <= (others => '0');
      end generate;

      north_connection: if routerPosition(i,X_ROUTERS,Y_ROUTERS)=BL or routerPosition(i,X_ROUTERS,Y_ROUTERS)=BC or routerPosition(i,X_ROUTERS,Y_ROUTERS)=BR or routerPosition(i,X_ROUTERS,Y_ROUTERS)=CL or routerPosition(i,X_ROUTERS,Y_ROUTERS)=CRX or routerPosition(i,X_ROUTERS,Y_ROUTERS)=CC generate
         rx(i)(NORTH)            <= tx(i+X_ROUTERS)(SOUTH);
         clock_rx(i)(NORTH)      <= clock_tx(i+X_ROUTERS)(SOUTH);
         credit_i(i)(NORTH)      <= credit_o(i+X_ROUTERS)(SOUTH);
         data_in(i)(NORTH)       <= data_out(i+X_ROUTERS)(SOUTH);
      end generate;

      --------------------------------------------------------------------------------
      --- SOUTH PORT CONNECTIONS -----------------------------------------------------
      ---------------------------------------------------------------------------
      south_grounding: if routerPosition(i,X_ROUTERS,Y_ROUTERS)=BL or routerPosition(i,X_ROUTERS,Y_ROUTERS)=BC or routerPosition(i,X_ROUTERS,Y_ROUTERS)=BR generate
         rx(i)(SOUTH)            <= '0';
         clock_rx(i)(SOUTH)      <= '0';
         credit_i(i)(SOUTH)      <= '0';
         data_in(i)(SOUTH)       <= (others => '0');
      end generate;

      south_connection: if routerPosition(i,X_ROUTERS,Y_ROUTERS)=TL or routerPosition(i,X_ROUTERS,Y_ROUTERS)=TC or routerPosition(i,X_ROUTERS,Y_ROUTERS)=TR or routerPosition(i,X_ROUTERS,Y_ROUTERS)=CL or routerPosition(i,X_ROUTERS,Y_ROUTERS)= CRX or routerPosition(i,X_ROUTERS,Y_ROUTERS)= CC generate
         rx(i)(SOUTH)            <= tx(i-X_ROUTERS)(NORTH);
         clock_rx(i)(SOUTH)      <= clock_tx(i-X_ROUTERS)(NORTH);
         credit_i(i)(SOUTH)      <= credit_o(i-X_ROUTERS)(NORTH);
         data_in(i)(SOUTH)       <= data_out(i-X_ROUTERS)(NORTH);
      end generate;

   end generate noc;


   -------------------------------------------------------------------------------
   --- TR PERIPHERAL -------------------------------------------------------------
   -------------------------------------------------------------------------------

   clock_rx(N0202)(NORTH) <= clock(N0202);

   network_interface : entity work.network_interface
   port map (
      clock => clock(N0202),
      reset => reset,
      rx => tx(N0202)(NORTH),
      tx => rx(N0202)(NORTH),
      credit_in => credit_o(N0202)(NORTH),
      credit_out => credit_i(N0202)(NORTH),
      data_in => data_out(N0202)(NORTH),
      data_out => data_in(N0202)(NORTH),

      per_clock => wb_clock,
      per_reset => wb_reset,
      address => wb_address,
      data_i => wb_data_i,
      data_o => wb_data_o,
      write_en  => wb_write_en,
      stb => wb_stb,
      ack => wb_ack,
      cyc => wb_cyc,
      stall => wb_stall
   );

   wb_memory : entity work.wb_256x2_bytes_memory
   port map(
      clock => wb_clock,
      reset => wb_reset,
      adr_i => wb_address,
      dat_i => wb_data_o,
      dat_o => wb_data_i,
      we_i  => wb_write_en,
      stb_i => wb_stb,
      ack_o => wb_ack,
      cyc_i => wb_cyc,
      stall_o => wb_stall
   );


end NOC;
