-- 
-- Add description here
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use work.HermesPackage.all;

entity test_peripheral is
    port(
        clock        : in std_logic;
        reset        : in std_logic;

        -- NOC interface
        rx           : in std_logic;
        tx           : out std_logic;
        credit_in    : in std_logic;
        credit_out   : out std_logic;
        data_in      : in regflit;
        data_out     : out regflit
    );
end;

architecture test of test_peripheral is

type interface_noc is (initializing, waiting, analysing, refusing, buffering);
signal interface_noc_state      : interface_noc;
signal interface_noc_next_state : interface_noc;

signal s_credit_out : std_logic;
signal s_data_in    : regflit;
signal s_data_out   : regflit;
signal s_tx         : std_logic;

signal s_has_message    : std_logic;
signal s_buffer_full    : std_logic;
signal s_analysing_done : std_logic;
signal s_buffering_done : std_logic;
signal s_refusing_done  : std_logic;
signal s_should_buffer  : std_logic;

-- Wishbone peripheral interface
signal per_reset : std_logic;
signal adr_o     : std_logic_vector(7 downto 0);
signal dat_i     : std_logic_vector(TAM_FLIT-1 downto 0);
signal dat_o     : std_logic_vector(TAM_FLIT-1 downto 0);
signal we_o      : std_logic;
signal stb_o     : std_logic;
signal ack_i     : std_logic;
signal cyc_o     : std_logic;

type service_type is (request, request_ack, request_nack, read_request, read_response, write_request, write_response);

signal header_flit_1 : std_logic_vector(TAM_FLIT-1 downto 0);
signal header_flit_2 : std_logic_vector(TAM_FLIT-1 downto 0);
signal header_flit_3 : std_logic_vector(TAM_FLIT-1 downto 0);

signal tmp_buffer : std_logic_vector(TAM_FLIT-1 downto 0);

signal buffering_data_counter   : integer;
signal refusing_data_counter    : integer;
signal buffering_header_counter : integer;
signal packet_length            : integer;

begin

    Wishbone_peripheral : entity work.test_wishbone_peripheral
    port map(
        clock => clock,
        reset => per_reset,
        adr_i => adr_o,
        dat_i => dat_o,
        dat_o => dat_i,
        we_i  => we_o,
        stb_i => stb_o,
        ack_o => ack_i,
        cyc_i => cyc_o
    );

    -- NOC interface control states
    interface_noc_next_state <= waiting when interface_noc_state = initializing else
                                analysing when interface_noc_state = waiting and s_has_message = '1' else
                                refusing when interface_noc_state = analysing and s_analysing_done = '1' and s_should_buffer = '0' else
                                buffering when interface_noc_state = analysing and s_analysing_done = '1' and s_should_buffer = '1' else
                                waiting when interface_noc_state = buffering and s_buffering_done = '1' else
                                waiting when interface_noc_state = refusing and s_refusing_done = '1' else
                                interface_noc_state;

    credit_out <= s_credit_out;
    data_out <= s_data_out;
    tx <= s_tx;

    process(reset, clock)
    begin
        if rising_edge(clock) then
            s_data_in <= data_in;
            packet_length <= to_integer(unsigned(header_flit_2(7 downto 0)));
        end if;
    end process;

    -- Input/Output signals control
    process(reset, clock)
    begin
        if rising_edge(clock) then
            case interface_noc_state is
                when initializing =>
                    s_credit_out <= '0';
                    s_data_out <= (others => '0');
                    s_tx <= '0';

                    -- clear internal signals
                    s_has_message <= '0';
                    s_buffer_full <= '0';
                    s_buffering_done <= '0';
                    s_refusing_done <= '0';
                    header_flit_1 <= (others => '0');
                    header_flit_2 <= (others => '0');
                    header_flit_3 <= (others => '0');
                    tmp_buffer    <= (others => '0');

                when waiting =>
                    -- Waiting for incomming messages
                    s_credit_out <= '1';
                    s_tx <= '0';

                    if rx = '1' then
                        s_has_message <= '1';
                    end if;

                    -- Save the first flit (service, target)
                    if s_has_message = '1' then
                        header_flit_1 <= s_data_in;
                    end if;

                    -- clear internal signals
                    buffering_header_counter <= 0;
                    s_should_buffer <= '0';
                    s_analysing_done <= '0';

                when analysing =>
                    if buffering_header_counter = 0 then
                        -- Save the second flit (packet lenght)
                        header_flit_2 <= s_data_in;
                        -- Save the third flit (service)
                        header_flit_3 <= data_in;

                        -- Stop receiving data
                        s_credit_out <= '0';

                    elsif buffering_header_counter = 1 then
                        s_credit_out <= '1';
                        -- TODO: Check by the service type and refuse the unknowns

                        if s_buffer_full = '1' then
                            s_should_buffer <= '0';
                        else
                            s_should_buffer <= '1';
                        end if;

                        s_analysing_done <= '1';
                    end if;

                    buffering_header_counter <= buffering_header_counter + 1;

                    -- clear internal signals
                    s_has_message <= '0';
                    s_buffering_done <= '0';
                    s_refusing_done <= '0';
                    buffering_data_counter <= 0;
                    refusing_data_counter <= 0;

                when refusing =>

                    if refusing_data_counter = packet_length - 3 then
                        s_refusing_done <= '1';
                    end if;

                    tmp_buffer <= s_data_in;
                    refusing_data_counter <= refusing_data_counter + 1;
                
                when buffering =>

                    if buffering_data_counter = packet_length - 3 then
                        s_buffering_done <= '1';
                        s_buffer_full <= '1';
                    end if;

                    tmp_buffer <= s_data_in;
                    buffering_data_counter <= buffering_data_counter + 1;

            end case;
        end if;
    end process;

    process(reset, clock)
    begin
        if reset = '1' then
            interface_noc_state <= initializing;
        elsif rising_edge(clock) then
            interface_noc_state <= interface_noc_next_state;
        end if;
    end process;

end architecture;
