-- 
-- Add description here
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

type interface_noc is (initializing, waiting, analysing, refusing, buffering);
signal interface_noc_state : interface_noc;
signal interface_noc_next_state : interface_noc;

signal s_credit_out : std_logic;
signal s_data_out : regflit;
signal s_tx : std_logic;

signal s_message_received : std_logic;
signal s_buffer_full : std_logic;

--signal buffer_in : packet;

begin

    -- NOC interface control states
    interface_noc_next_state <= waiting when interface_noc_state = initializing else
                                analysing when interface_noc_state = waiting and s_has_message = '1' else
                                refusing when interface_noc_state = analysing and s_buffer_full = '1' else
                                buffering when interface_noc_state = analysing and s_buffer_full = '0' else
                                interface_noc_state;

    credit_out <= s_credit_out;
    data_out <= s_data_out;
    tx <= s_tx;

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

                when waiting =>
                    -- Waiting for incomming messages
                    s_credit_out <= '1';
                    s_tx <= '0';

                    if rx = '1' then
                        s_has_message <= '1';
                    end if;

                when analysing =>

                when refusing =>
                
                when buffering =>
                    -- TODO: Save request
                    s_buffer_full <= '1';

            end case;
        end if;
    end process;

    process(reset, clock)
    begin
        if reset = '1' then
            interface_noc_state = initializing;
        elsif rising_edge(clock) then
            interface_noc_state = interface_noc_next_state;
        end if;
    end process;

end architecture;
