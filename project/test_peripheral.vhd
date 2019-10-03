-- source /soft64/source_gaph; module load modelsim; cd lab1/noc1; vsim -do simulate.do
--
-- Peripheral made only for testing purposes.
-- This module acts as procuder and consumer by
-- sending 1 message when 2 messages are received 
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.HermesPackage.all;

entity test_peripheral is
    port(
        clock : in std_logic;
        reset : in std_logic;

        -- NOC interface
        rx : in std_logic;
        tx : out std_logic;
        credit_in : in std_logic;
        credit_out : out std_logic;
        data_in : in regflit;
        data_out : out regflit
    );
end;

architecture test of test_peripheral is

type interface_noc is (initializing, waiting, receiving, sending, sending_back);
type interface_wishbone is (idle, initializing, sending, receiving, waiting);
signal interface_noc_state : interface_noc;
signal interface_wishbone_state : interface_wishbone;

signal s_reset : std_logic;
signal s_credit_out : std_logic;
signal s_data_out : regflit;
signal s_tx : std_logic;
signal initializing_done : std_logic;
signal receiving_done : std_logic;
signal sending_done : std_logic;
signal received_counter : integer range 0 to 255;
signal sent_counter : integer range 0 to 255;
signal buffer_in : packet;
signal result : regflit;
signal buffer_out : packet;
signal has_awnser : std_logic;
signal sending_back_done : std_logic;
signal init_periph : std_logic;
signal send_back_counter : integer range 0 to 255;

-- Wishbone peripheral interface
signal per_reset : std_logic;
signal adr_o     : std_logic_vector(7 downto 0);
signal dat_i     : std_logic_vector(TAM_FLIT-1 downto 0);
signal dat_o     : std_logic_vector(TAM_FLIT-1 downto 0);
signal we_o      : std_logic;
signal stb_o     : std_logic;
signal ack_i     : std_logic;
signal cyc_o     : std_logic;

signal w_initializing_done : std_logic;
signal w_sending_done : std_logic;
signal w_waiting_done : std_logic;
signal w_receiving_done : std_logic;
signal w_sent_counter : integer range 0 to 255;

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
    interface_noc_state <= initializing when s_reset = '1' else
                       waiting when interface_noc_state = initializing and initializing_done = '1' else
                       receiving when interface_noc_state = waiting and rx = '1' and s_credit_out = '1' else
                       sending when interface_noc_state = waiting and s_tx = '1' and credit_in = '1' else
                       sending when interface_noc_state = receiving and receiving_done = '1' else
                       waiting when interface_noc_state = sending and interface_wishbone_state = waiting and has_awnser = '0' else
                       sending_back when interface_noc_state = sending and interface_wishbone_state = idle and has_awnser = '1' else
                       waiting when interface_noc_state = sending_back and sending_back_done = '1' else
                       interface_noc_state;

    credit_out <= s_credit_out;
    data_out <= s_data_out;
    tx <= s_tx;

    -- Input/Output signals control
    process(reset, clock)
    begin
        if (rising_edge(clock)) then
            case interface_noc_state is
                when initializing =>
                    initializing_done <= '1';

                    s_credit_out <= '0';
                    s_data_out <= (others => '0');
                    s_tx <= '0';
                    sent_counter <= 0;
                    per_reset <= '1';
                    init_periph <= '0';

                when waiting =>
                    per_reset <= '0';
                    received_counter <= 0;
                    receiving_done <= '0';
                    sending_done <= '0';
                    sending_back_done <= '0';
                    has_awnser <= '0';

                    -- Wait for incomming messages
                    s_credit_out <= '1';
                    s_tx <= '0';

                when receiving =>
                    if received_counter = PACKET_LEN then
                        receiving_done <= '1';
                        s_credit_out <= '0';
                        init_periph <= '1';
                    else
                        if rx = '1' then
                            received_counter <= received_counter + 1;
                            buffer_in(received_counter) <= data_in;
                        end if;
                    end if;

                when sending =>
                    init_periph <= '0';
                    if w_sending_done = '1' or w_receiving_done = '1' then
                        if w_receiving_done = '1' then
                                has_awnser <= '1';
                                send_back_counter <= 0;
                                buffer_out(0) <= x"0000";--x"C122", x"000F", x"0034"
                                buffer_out(1) <= x"000F";
                                buffer_out(2) <= x"2234";
                                buffer_out(3) <= result;
                                buffer_out(4) <= (others => '0');
                                buffer_out(5) <= (others => '0');
                                buffer_out(6) <= (others => '0');
                                buffer_out(7) <= (others => '0');
                                buffer_out(8) <= (others => '0');
                                buffer_out(9) <= (others => '0');
                                buffer_out(10) <= (others => '0');
                                buffer_out(11) <= (others => '0');
                                buffer_out(12) <= (others => '0');
                                buffer_out(13) <= (others => '0');
                                buffer_out(14) <= (others => '0');
                                buffer_out(15) <= (others => '0');
                                buffer_out(16) <= (others => '0');
                                sending_done <= '1';
                        elsif w_sending_done = '1' then
                            sending_done <= '1';
                        end if;
                    else
                        sending_done <= '0';
                    end if;
                
                when sending_back =>
                    if credit_in = '1' then
                        s_tx <= '1';

                        if send_back_counter = PACKET_LEN then
                            sending_back_done <= '0';--TODO: finish the transaction gracefully, this may block other operations to this peripheral
                        else
                            send_back_counter <= send_back_counter + 1;
                            s_data_out <= buffer_out(send_back_counter);
                        end if;
                    end if;
            end case;
        end if;
    end process;

    -- Wishbone interface control states
    interface_wishbone_state <= idle when s_reset = '1' else
                          initializing when interface_wishbone_state = idle and interface_noc_state = sending and init_periph = '1' else
                          receiving when interface_wishbone_state = initializing and w_initializing_done = '1' and we_o = '0' else
                          sending when interface_wishbone_state = initializing and w_initializing_done = '1' and we_o = '1' else
                          waiting when interface_wishbone_state = sending and w_sending_done = '1' else
                          idle when interface_wishbone_state = receiving and w_receiving_done = '1' else
                          idle when interface_wishbone_state = waiting and w_waiting_done = '1' else 
                          interface_wishbone_state;

    cyc_o <= '1' when interface_wishbone_state = initializing else 
             '0';

    stb_o <= '1' when interface_wishbone_state = initializing else
             '0';

    process(reset, clock)
    begin
        if (rising_edge(clock)) then
            case interface_wishbone_state is
                when idle =>
                    we_o  <= '0';
                    adr_o <= x"00";
                    dat_o <= (others => '0');
                    w_initializing_done <= '0';
                    w_sent_counter <= 3; -- skip the header (1st two flits)
                    w_waiting_done <= '0';
                when initializing =>
                    w_receiving_done <= '0';
                    if ack_i = '1' then
                        we_o <= buffer_in(0)(METADEFLIT); -- read or write
                        adr_o <= buffer_in(2)(METADEFLIT-1 downto 0); -- the low part contains peripheral address
                        w_initializing_done <= '1';
                        dat_o <= buffer_in(w_sent_counter);
                        w_sent_counter <= w_sent_counter + 1;
                    end if;
                when sending =>
                    if w_sent_counter = 5 then -- send only two flits (two numbers to operate)
                        w_sending_done <= '1';
                        w_sent_counter <= 0;
                    else
                        if ack_i = '1' then
                            w_sent_counter <= w_sent_counter + 1;
                        end if;
                        dat_o <= buffer_in(w_sent_counter);
                    end if;
                when receiving =>
                    if ack_i = '1' then
                        result <= dat_i;
                        w_receiving_done <= '1';
                    end if;
                when waiting =>
                    if ack_i = '1' then
                        w_waiting_done <= '1';
                        w_sending_done <= '0';
                    end if;
            end case;
        end if;
    end process;

    process(reset, clock)
    begin
        if (rising_edge(clock)) then
            if reset = '1' then
                s_reset <= '1';
            else
                s_reset <= '0';
            end if;
        end if;
    end process;

end architecture;
