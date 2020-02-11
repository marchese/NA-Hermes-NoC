--
-- Add description here
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use work.HermesPackage.all;

entity requests_packaging is
   generic (
      ADDR_LENGTH: integer := 8;
      DATA_LENGTH: integer := 16
   );
   port(
      clock            : in  std_logic;
      reset            : in  std_logic;

      -- Control bus
      send_ack         : in  std_logic;
      send_nack        : in  std_logic;
      nack_task_id     : in  std_logic_vector(DATA_LENGTH-1 downto 0);
      respond_read     : in  std_logic;
      send_read_per    : out std_logic;
      data_i_per       : in  std_logic_vector(DATA_LENGTH-1 downto 0);
      ack_per          : in  std_logic;
      respond_write    : in  std_logic;
      request_sent     : out std_logic;
      request          : in  ni_service_request;
      response_counter : out integer;

      -- Protocol bus
      tx               : out std_logic;
      credit_in        : in  std_logic;
      data_out         : out std_logic_vector(DATA_LENGTH-1 downto 0)
   );
end;

architecture main of requests_packaging is

type response_sender is (waiting, sending_request_ack, sending_request_nack, sending_write_response, sending_read_response);
signal response_sender_state      : response_sender;
signal send_response_counter      : integer;

signal s_request_sent             : std_logic;

signal s_data_out                 : std_logic_vector(DATA_LENGTH-1 downto 0);
signal s_tx                       : std_logic;

begin
   response_counter <= send_response_counter;

   data_out <= (others => '0') when reset = '1' else
               data_i_per when send_response_counter >= read_response_header_size and credit_in = '1' and ack_per = '1' else
               s_data_out;
   
   tx <= s_tx;

   request_sent <= s_request_sent;

   response_sender_state <= waiting when reset = '1' else
                              sending_request_ack when response_sender_state = waiting and send_ack = '1' else
                              sending_request_nack when response_sender_state = waiting and send_nack = '1' else
                              sending_write_response when response_sender_state = waiting and respond_write = '1' else
                              sending_read_response when response_sender_state = waiting and respond_read = '1' else
                              waiting when response_sender_state = sending_request_ack and s_request_sent = '1' else
                              waiting when response_sender_state = sending_request_nack and s_request_sent = '1' else
                              waiting when response_sender_state = sending_write_response and s_request_sent = '1' else
                              waiting when response_sender_state = sending_read_response and s_request_sent = '1' else
                              response_sender_state;

   response_sender_fsm: process(reset, clock)
      variable req_pckt : service_request_packet;
      variable write_ack_pckt : service_write_response_packet;
   begin
      if rising_edge(clock) then
         case response_sender_state is

               when waiting =>
                  s_tx <= '0';
                  s_data_out <= (others => '0');
                  s_request_sent <= '0';
                  send_response_counter <= 0;
                  send_read_per <= '0';

               when sending_request_ack =>

                  req_pckt(0) := x"0000";
                  req_pckt(1) := x"0003";
                  req_pckt(2) := service_request_ack;
                  req_pckt(3) := x"FAFA";
                  req_pckt(4) := request.task_id;

                  if credit_in = '1' and send_response_counter < req_pckt'length then
                     s_tx <= '1';
                     s_data_out <= req_pckt(send_response_counter);
                     send_response_counter <= send_response_counter + 1;
                  elsif credit_in = '1' and send_response_counter = req_pckt'length then
                     s_tx <= '0';
                     s_data_out <= (others => '0');
                     s_request_sent <= '1';
                  end if;

               when sending_request_nack =>

                  req_pckt(0) := x"0000";
                  req_pckt(1) := x"0003";
                  req_pckt(2) := service_request_nack;
                  req_pckt(3) := x"FAFA";
                  req_pckt(4) := nack_task_id;

                  if credit_in = '1' and send_response_counter < req_pckt'length then
                     s_tx <= '1';
                     s_data_out <= req_pckt(send_response_counter);
                     send_response_counter <= send_response_counter + 1;
                  elsif credit_in = '1' and send_response_counter = req_pckt'length then
                     s_tx <= '0';
                     s_data_out <= (others => '0');
                     s_request_sent <= '1';
                  end if;

               when sending_write_response =>

                  write_ack_pckt(0) := x"0000";
                  write_ack_pckt(1) := x"0004";
                  write_ack_pckt(2) := service_write_response;
                  write_ack_pckt(3) := x"FAFA";
                  write_ack_pckt(4) := request.task_id;
                  write_ack_pckt(5) := x"0001";

                  if credit_in = '1' and send_response_counter < write_ack_pckt'length then
                     s_tx <= '1';
                     s_data_out <= write_ack_pckt(send_response_counter);
                     send_response_counter <= send_response_counter + 1;
                  elsif credit_in = '1' and send_response_counter = write_ack_pckt'length then
                     s_tx <= '0';
                     s_data_out <= (others => '0');
                     s_request_sent <= '1';
                  end if;

               when sending_read_response =>
                  -- TODO: Fill flit(0) with target PE number
                  -- TODO: Fill flit(3) with peripheral id
                  write_ack_pckt(0) := x"0000";
                  write_ack_pckt(1) := request.size + 4;
                  write_ack_pckt(2) := service_read_response;
                  write_ack_pckt(3) := x"FAFA";
                  write_ack_pckt(4) := request.task_id;
                  write_ack_pckt(5) := x"0001";

                  if send_response_counter < write_ack_pckt'length then
                     if credit_in = '1' then 
                        s_tx <= '1';
                        s_data_out <= write_ack_pckt(send_response_counter);
                        send_response_counter <= send_response_counter + 1;
                     end if;
                  elsif send_response_counter - write_ack_pckt'length = request.size then
                     if credit_in = '1' then 
                        s_tx <= '0';
                        s_data_out <= (others => '0');
                        s_request_sent <= '1';
                        send_read_per <= '0';
                     end if;
                  elsif send_response_counter >= write_ack_pckt'length then
                     if credit_in = '1' then
                        send_read_per <= '1';
                        if ack_per = '1' then
                           send_response_counter <= send_response_counter + 1;
                           s_tx <= '1';
                        else
                           s_tx <= '0';
                        end if;
                     else
                        s_tx <= '0';
                     end if;
                  end if;
         end case;
      end if;
   end process;

end architecture main;