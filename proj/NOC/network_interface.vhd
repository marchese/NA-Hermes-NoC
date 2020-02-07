--
-- Add description here
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use work.HermesPackage.all;

entity network_interface is
    port(
        clock        : in std_logic;
        reset        : in std_logic;

        -- NOC interface
        rx           : in std_logic;
        tx           : out std_logic;
        credit_in    : in std_logic;
        credit_out   : out std_logic;
        data_in      : in regflit;
        data_out     : out regflit;

        -- Wishbone peripheral interface
        per_reset    : out std_logic;
        address      : out std_logic_vector(7 downto 0);
        data_i       : in  std_logic_vector(TAM_FLIT-1 downto 0);
        data_o       : out std_logic_vector(TAM_FLIT-1 downto 0);
        write_en     : out std_logic;
        stb          : out std_logic;
        ack          : in  std_logic;
        cyc          : out std_logic;
        stall        : in  std_logic
    );
end;

architecture wishbone of network_interface is

type interface_noc is (initializing, waiting, analysing, refusing, buffering);
signal interface_noc_state      : interface_noc;

signal s_data_in    : regflit;
signal s_data_out   : regflit;
signal s_tx         : std_logic;
signal s_rx         : std_logic;

signal s_credit_out_analysis   : std_logic;
signal s_credit_out_processing : std_logic;

signal s_has_message         : std_logic;
signal s_buffer_full         : std_logic;
signal s_initialization_done : std_logic;
signal s_analysing_done      : std_logic;
signal s_buffering_done      : std_logic;
signal s_refusing_done       : std_logic;
signal s_should_buffer       : std_logic;
signal is_read               : std_logic;

signal header_flit_1 : std_logic_vector(TAM_FLIT-1 downto 0);
signal header_flit_2 : std_logic_vector(TAM_FLIT-1 downto 0);
signal header_flit_3 : std_logic_vector(TAM_FLIT-1 downto 0);
signal source_pe     : std_logic_vector(TAM_FLIT-1 downto 0);

signal tmp_buffer : std_logic_vector(TAM_FLIT-1 downto 0);

signal buffering_data_counter   : integer;
signal refusing_data_counter    : integer;
signal buffering_header_counter : integer;
signal packet_length            : integer;

signal service_request_record   : NI_SERVICE_REQUEST;

-- Signals to control de Request Record CAM
signal s_rrcam_addra  : std_logic_vector(7 downto 0);
signal s_rrcam_addrb  : std_logic_vector(7 downto 0);
signal s_rrcam_clka   : std_logic;
signal s_rrcam_clkb   : std_logic;
signal s_rrcam_dina   : NI_SERVICE_REQUEST;
signal s_rrcam_doutb  : NI_SERVICE_REQUEST;
signal s_rrcam_enb    : std_logic;
signal s_rrcam_wea    : std_logic;

signal request_record_wp          : integer;
signal request_record_rp          : integer := 0;

type internal_processing is (waiting, accepting, analysing, discarding, receiving_from_noc_to_peripheral, responding, working, terminating);
signal internal_processing_state  : internal_processing;

signal current_request_analysis   : NI_SERVICE_REQUEST;
signal current_request_processing : NI_SERVICE_REQUEST;
signal s_rrcam_has_data           : std_logic;
signal data_ready                 : std_logic;
signal request_accepted           : std_logic;
signal request_approved           : std_logic;
signal analysing_done             : std_logic;
signal analysing_counter          : integer;
signal processing_source_pe       : std_logic_vector(TAM_FLIT-1 downto 0);
signal processing_task_id         : std_logic_vector(TAM_FLIT-1 downto 0);
signal processing_size            : std_logic_vector(TAM_FLIT-1 downto 0);
signal send_response_counter      : integer;

signal write_request_processing   : std_logic;
signal read_request_processing    : std_logic;
signal write_request_done         : std_logic;
signal read_request_done          : std_logic;
signal nack_sent                  : std_logic;

type response_sender is (waiting, sending_request_ack, sending_request_nack, sending_write_response, sending_read_response);
signal response_sender_state      : response_sender;
signal request_ack_sent           : std_logic;
signal send_ack_request           : std_logic;
signal send_nack_request          : std_logic;
signal waiting_write_request      : std_logic;
signal waiting_nack_sent          : std_logic;
signal discard_done               : std_logic;
signal discarding_counter         : integer;
signal receiving_done             : std_logic;
signal responding_done            : std_logic;
signal receiving_counter          : integer;
signal send_write_response        : std_logic;
signal send_read_response         : std_logic;

-- Wishbone peripheral interface
signal s_per_reset  : std_logic;
type wishbone_sender is (waiting, sending_write, sending_read, cooldown);
signal wishbone_sender_state      : wishbone_sender;
signal send_write                 : std_logic;
signal s_cyc                      : std_logic;
signal s_stb                      : std_logic;
signal s_data_o                   : std_logic_vector(TAM_FLIT-1 downto 0);
signal peripheral_address         : std_logic_vector(7 downto 0);
signal peripheral_address_read    : std_logic_vector(7 downto 0);

begin

   -- Signals to control de Request Record CAM
   s_rrcam_clka <= clock;
   s_rrcam_clkb <= clock;
   s_rrcam_has_data <= '1' when request_record_wp > request_record_rp else '0';

   -- Send wishbone requests to the peripheral
   per_reset <= reset or s_per_reset;

   cyc <= s_cyc;
   stb <= s_stb;
   data_o <= s_data_o when wishbone_sender_state = sending_write else (others => '0');

   wishbone_sender_state <= waiting when s_per_reset = '1' else
                              sending_write when wishbone_sender_state = waiting and internal_processing_state = receiving_from_noc_to_peripheral and send_write = '1' else
                              sending_read when wishbone_sender_state = waiting and internal_processing_state = responding and send_read_response = '1' else
                              cooldown when wishbone_sender_state = sending_write and send_write = '0' and ack = '1' else
                              cooldown when wishbone_sender_state = sending_read and send_read_response = '0' and ack = '1' else
                              waiting when wishbone_sender_state = cooldown and s_cyc = '0' and s_stb = '0' else
                              wishbone_sender_state;

   wishbone_sender_fsm: process(reset, clock)
   begin
      if rising_edge(clock) then
         case wishbone_sender_state is
            when waiting =>
               address <= (others => '0');
               s_data_o <= (others => '0');
               write_en <= '0';
               s_stb <= '0';
               s_cyc <= '0';
            when sending_write =>
               if send_write = '1' then
                  s_cyc <= '1';
                  s_stb <= '1';
                  write_en <= '1';
                  s_data_o <= s_data_in;
                  address <= peripheral_address;
               end if;
            when cooldown =>
               s_cyc <= '0';
               s_stb <= '0';
               write_en <= '0';
            when sending_read =>
               if send_read_response = '1' then
                  address <= peripheral_address_read;
                  s_cyc <= '1';
                  s_stb <= '1';
                  write_en <= '0';
               end if;
         end case;
      end if;
   end process wishbone_sender_fsm;

   -- Send responses to the network
   response_sender_state <= waiting when reset = '1' else
                              sending_request_ack when response_sender_state = waiting and internal_processing_state = accepting and send_ack_request = '1' else
                              sending_request_nack when response_sender_state = waiting and interface_noc_state = refusing and send_nack_request = '1' else
                              sending_write_response when response_sender_state = waiting and internal_processing_state = responding and send_write_response = '1' else
                              sending_read_response when response_sender_state = waiting and internal_processing_state = responding and send_read_response = '1' else
                              waiting when response_sender_state = sending_request_ack and request_ack_sent = '1' else
                              waiting when response_sender_state = sending_request_nack and request_ack_sent = '1' else
                              waiting when response_sender_state = sending_write_response and request_ack_sent = '1' else
                              waiting when response_sender_state = sending_read_response and request_ack_sent = '1' else
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
                  request_ack_sent <= '0';
                  send_response_counter <= 0;

               when sending_request_ack =>

                  req_pckt(0) := x"0000";
                  req_pckt(1) := x"0003";
                  req_pckt(2) := service_request_ack;
                  req_pckt(3) := x"FAFA";
                  req_pckt(4) := current_request_processing.task_id;

                  if credit_in = '1' and send_response_counter < req_pckt'length then
                     s_tx <= '1';
                     s_data_out <= req_pckt(send_response_counter);
                     send_response_counter <= send_response_counter + 1;
                  elsif credit_in = '1' and send_response_counter = req_pckt'length then
                     s_tx <= '0';
                     s_data_out <= (others => '0');
                     request_ack_sent <= '1';
                  end if;

               when sending_request_nack =>

                  req_pckt(0) := x"0000";
                  req_pckt(1) := x"0003";
                  req_pckt(2) := service_request_nack;
                  req_pckt(3) := x"FAFA";
                  req_pckt(4) := current_request_analysis.task_id;

                  if credit_in = '1' and send_response_counter < req_pckt'length then
                     s_tx <= '1';
                     s_data_out <= req_pckt(send_response_counter);
                     send_response_counter <= send_response_counter + 1;
                  elsif credit_in = '1' and send_response_counter = req_pckt'length then
                     s_tx <= '0';
                     s_data_out <= (others => '0');
                     request_ack_sent <= '1';
                  end if;

               when sending_write_response =>

                  write_ack_pckt(0) := x"0000";
                  write_ack_pckt(1) := x"0004";
                  write_ack_pckt(2) := service_write_response;
                  write_ack_pckt(3) := x"FAFA";
                  write_ack_pckt(4) := current_request_processing.task_id;
                  write_ack_pckt(5) := x"0001";

                  if credit_in = '1' and send_response_counter < write_ack_pckt'length then
                     s_tx <= '1';
                     s_data_out <= write_ack_pckt(send_response_counter);
                     send_response_counter <= send_response_counter + 1;
                  elsif credit_in = '1' and send_response_counter = write_ack_pckt'length then
                     s_tx <= '0';
                     s_data_out <= (others => '0');
                     request_ack_sent <= '1';
                  end if;

               when sending_read_response =>
               -- Send read response
                  write_ack_pckt(0) := x"0000";
                  write_ack_pckt(1) := processing_size + 4;
                  write_ack_pckt(2) := service_read_response;
                  write_ack_pckt(3) := x"FAFA";
                  write_ack_pckt(4) := current_request_processing.task_id;
                  write_ack_pckt(5) := x"0001";

                  if credit_in = '1' and send_response_counter < write_ack_pckt'length then
                     s_tx <= '1';
                     s_data_out <= write_ack_pckt(send_response_counter);
                     send_response_counter <= send_response_counter + 1;
                  elsif credit_in = '1' and send_response_counter = processing_size + 6 then
                     s_tx <= '0';
                     s_data_out <= (others => '0');
                     request_ack_sent <= '1';
                  elsif credit_in = '1' and send_response_counter >= write_ack_pckt'length then
                     s_tx <= '1';
                     if ack = '1' then
                        s_data_out <= data_i;
                     end if;
                  end if;

                  if credit_in = '1' then
                     send_response_counter <= send_response_counter + 1;
                  end if;
         end case;
      end if;
   end process;

   peripheral_address_read <= std_logic_vector(to_unsigned(send_response_counter, 8)) when response_sender_state = sending_read_response else (others => '0');

   -- Read from requests memory
   internal_processing_state <= waiting when reset = '1' else
                                 accepting when internal_processing_state = waiting and data_ready = '1' else
                                 analysing when internal_processing_state = accepting and request_accepted = '1' else
                                 discarding when internal_processing_state = analysing and request_approved = '0' and analysing_done = '1' else
                                 receiving_from_noc_to_peripheral when internal_processing_state = analysing and request_approved = '1' and analysing_done = '1' and is_read = '0' else
                                 waiting when internal_processing_state = discarding and discard_done = '1' else
                                 responding when internal_processing_state = receiving_from_noc_to_peripheral and receiving_done = '1' else
                                 responding when internal_processing_state = analysing and request_approved = '1' and analysing_done = '1' and is_read = '1' else
                                 waiting when internal_processing_state = responding and request_ack_sent = '1' else
                                 internal_processing_state;

   internal_processing_FSM: process(reset, clock)
      variable req_pckt : service_request_packet;
   begin
      if rising_edge(clock) then
         case internal_processing_state is
               when waiting =>
                  s_rrcam_enb <= '0';
                  s_rrcam_addrb <= (others => '0');
                  current_request_processing <= ((others => '0'), (others => '0'), (others => '0'));
                  data_ready <= '0';
                  request_accepted <= '0';
                  request_approved <= '0';
                  analysing_done <= '0';
                  write_request_done <= '0';
                  nack_sent <= '0';
                  send_ack_request <= '0';
                  discard_done <= '0';
                  discarding_counter <= 0;
                  receiving_done <= '0';
                  responding_done <= '0';
                  receiving_counter <= 0;
                  send_write_response <= '0';
                  send_read_response <= '0';
                  send_write <= '0';
                  s_per_reset <= '0';
                  is_read <= '0';
                  analysing_counter <= 0;
                  processing_source_pe <= (others => '0');
                  processing_task_id <= (others => '0');
                  processing_size <= (others => '0');
                  s_credit_out_processing <= '1';
                  peripheral_address <= (others => '0');

                  if discard_done = '0' then
                     waiting_write_request <= '0';
                  end if;

                  -- increments the read pointer when comming from responding state so the operation won't be retrieved again from the records memory
                  if request_ack_sent = '1' and responding_done = '1' then
                     request_record_rp <= request_record_rp + 1;
                  elsif s_rrcam_has_data = '1'then
                     -- read the request from memory
                     s_rrcam_addrb <= std_logic_vector(to_unsigned(request_record_rp, 8));
                     s_rrcam_enb <= '1';
                     data_ready <= '1';
                  end if;

               when accepting =>

                  if data_ready = '1' then
                     data_ready <= '0';
                     current_request_processing <= s_rrcam_doutb;
                  end if;

                  if data_ready = '0' and waiting_write_request = '0' then
                     -- After reading the request from memory sends an ack message in order to accept it
                     send_ack_request <= '1';
                     waiting_write_request <= '1';
                  else
                     send_ack_request <= '0';
                  end if;

                  -- TODO: Implement a time-out mechanism in case where the write request message is never sent to the NI
                  if (write_request_processing = '1' or read_request_processing = '1') and waiting_write_request = '1' then
                     request_accepted <= '1';
                     processing_source_pe <= data_in;
                  end if;

               when analysing =>
                  -- TODO: Security check using criptography keys in the future
                  is_read <= read_request_processing;
                  
                  if analysing_counter = 0 and rx = '1' then
                     processing_task_id <= data_in;
                  elsif analysing_counter = 1 and rx = '1' then
                     processing_size <= data_in;
                     s_credit_out_processing <= '0';
                  elsif analysing_counter = 2 then
                     -- take a decision if this is an authorized request
                     s_credit_out_processing <= '1';
                     analysing_done <= '1';
                     if processing_task_id = current_request_processing.task_id then
                        request_approved <= '1';
                     else
                        waiting_write_request <= '1';
                        request_approved <= '0';
                     end if;
                  end if;

                  if rx = '1' then
                     analysing_counter <= analysing_counter + 1;
                  end if;

               when discarding =>
                  -- discard the data since the request is already accepted but it didn't pass in some security check
                  if discarding_counter = packet_length - 3 then
                     discard_done <= '1';
                     write_request_done <= '1';
                  end if;

                  discarding_counter <= discarding_counter + 1;

               when receiving_from_noc_to_peripheral =>
                  -- send data to the peripheral
                  if s_rx <= '1' then
                     if receiving_counter = 0 then
                        send_write <= '1';
                     end if;

                     if receiving_counter = packet_length - 3 then
                        write_request_done <= '1';
                        receiving_done <= '1';
                        send_write <= '0';
                     end if;

                     receiving_counter <= receiving_counter + 1;
                     peripheral_address <= std_logic_vector(to_unsigned(receiving_counter, 8));
                  else
                     send_write <= '0';
                  end if;

               when responding =>
                  if is_read = '0' then
                     send_write_response <= '1';
                  else
                     send_read_response <= '1';
                  end if;
                  responding_done <= '1';

               when working =>
               when terminating =>
         end case;
      end if;
   end process internal_processing_FSM;

   -- NOC interface control states
   interface_noc_state <= initializing when reset = '1' else
                           waiting      when interface_noc_state = initializing and s_initialization_done = '1' else
                           analysing    when interface_noc_state = waiting and s_has_message = '1' else
                           waiting      when interface_noc_state = analysing and write_request_done = '1' else
                           waiting      when interface_noc_state = analysing and response_sender_state = sending_read_response and request_ack_sent = '1' else
                           waiting      when interface_noc_state = analysing and read_request_done = '1' else
                           refusing     when interface_noc_state = analysing and s_analysing_done = '1' and s_should_buffer = '0' else
                           buffering    when interface_noc_state = analysing and s_analysing_done = '1' and s_should_buffer = '1' else
                           waiting      when interface_noc_state = buffering and s_buffering_done = '1' else
                           waiting      when interface_noc_state = refusing and s_refusing_done = '1' else
                           interface_noc_state;

   credit_out <= s_credit_out_analysis and s_credit_out_processing;
   data_out <= s_data_out;
   tx <= s_tx;
   packet_length <= to_integer(unsigned(header_flit_2(7 downto 0)));

   process(reset, clock)
   begin
      if rising_edge(clock) then
         s_data_in <= data_in;
         s_rx <= rx;
      end if;
   end process;

   -- Input/Output signals control
   process(reset, clock)
   begin
      if rising_edge(clock) then
         case interface_noc_state is
               when initializing =>
                  s_credit_out_analysis <= '0';

                  -- clear internal signals
                  s_has_message <= '0';
                  s_buffer_full <= '0';
                  s_buffering_done <= '0';
                  s_refusing_done <= '0';
                  header_flit_1 <= (others => '0');
                  header_flit_2 <= (others => '0');
                  header_flit_3 <= (others => '0');
                  tmp_buffer <= (others => '0');
                  request_record_wp <= 0;

                  s_initialization_done <= '1';

               when waiting =>
                  -- Waiting for incomming messages
                  s_credit_out_analysis <= '1';

                  if rx = '1' then
                     s_has_message <= '1';
                     -- Save the first flit (target, i/o border)
                     header_flit_1 <= s_data_in;
                  end if;

                  -- clear internal signals
                  buffering_header_counter <= 0;
                  s_should_buffer <= '0';
                  s_analysing_done <= '0';
                  s_rrcam_addra <= (others => '0');
                  s_rrcam_wea <= '0';
                  s_rrcam_dina <= ((others => '0'), (others => '0'), (others => '0'));
                  send_nack_request <= '0';
                  waiting_nack_sent <= '0';
                  write_request_processing <= '0';
                  read_request_processing <= '0';
                  current_request_analysis.task_id <= (others => '0');

               when analysing =>
                  if buffering_header_counter = 0 then
                     -- Save the second flit (packet lenght)
                     if rx = '1' then
                        header_flit_2 <= data_in;
                        buffering_header_counter <= buffering_header_counter + 1;
                     end if;

                  elsif buffering_header_counter = 1 then
                     -- Save the third flit (service)
                     if rx = '1' then
                        header_flit_3 <= data_in;
                        buffering_header_counter <= buffering_header_counter + 1;
                        -- Stop receiving data
                        s_credit_out_analysis <= '0';
                     end if;
                  else
                     s_credit_out_analysis <= '1';
                     -- Service request
                     if header_flit_3 = service_request then
                           -- Refuse the request if buffer is full
                           if s_buffer_full = '1' then
                              s_should_buffer <= '0';
                           else
                              s_should_buffer <= '1';
                           end if;
                           s_analysing_done <= '1';

                     elsif header_flit_3 = service_request_write then
                           -- Activate the "Processing" state machine to process the input from the network and write to the peripheral
                           if internal_processing_state = accepting then
                              write_request_processing <= '1';
                           elsif write_request_processing = '0' then
                              s_should_buffer <= '0';
                              s_analysing_done <= '1';
                           end if;

                     elsif header_flit_3 = service_request_read then
                           -- Activate the "Processing" state machine to read from the peripheral and send the response to the network
                           if internal_processing_state = accepting then
                              read_request_processing <= '1';
                           elsif read_request_processing = '0' then
                              s_should_buffer <= '0';
                              s_analysing_done <= '1';
                           end if;

                     else
                           -- Unknown services are just ignored without sending anything back to the network as response
                           s_should_buffer <= '0';
                           s_analysing_done <= '1';
                     end if;
                  end if;

                  -- clear internal signals
                  s_has_message <= '0';
                  s_buffering_done <= '0';
                  s_refusing_done <= '0';
                  buffering_data_counter <= 0;
                  refusing_data_counter <= 0;

               when refusing =>

                  if rx = '1' then
                     refusing_data_counter <= refusing_data_counter + 1;
                  end if;

                  if header_flit_3 = service_request then
                     if refusing_data_counter = 1 and rx = '1' then
                           -- Activate the "Processing" state machine to send a REQUEST_NACK back to the network
                           send_nack_request <= '1';
                           current_request_analysis.task_id <= data_in;
                           waiting_nack_sent <= '1';
                     end if;
                  else
                     if packet_length > 3 then
                        if refusing_data_counter = packet_length - 4 then
                           s_refusing_done <= '1';
                        end if;
                     else
                        if refusing_data_counter = 1 then
                           s_refusing_done <= '1';
                        end if;
                     end if;
                  end if;

                  if waiting_nack_sent = '1' then
                     send_nack_request <= '0';
                     if request_ack_sent = '1' then
                        s_refusing_done <= '1';
                     end if;
                  end if;

               when buffering =>
                  if rx = '1' then
                     if buffering_data_counter = 0 then
                        source_pe <= data_in;
                     elsif buffering_data_counter = 1 then
                        service_request_record.border_dir <= header_flit_1;
                        service_request_record.source_pe <= source_pe;
                        service_request_record.task_id <= data_in;
                     end if;

                     buffering_data_counter <= buffering_data_counter + 1;
                  end if;

                  if buffering_data_counter = 2 then
                     s_buffering_done <= '1';
                     if request_record_wp + 2 = request_record_rp + 1 then
                        s_buffer_full <= '1';
                     end if;

                     -- Save record into a memory
                     s_rrcam_addra <= std_logic_vector(to_unsigned(request_record_wp, 8));
                     s_rrcam_wea <= '1';
                     s_rrcam_dina <= service_request_record;
                     request_record_wp <= request_record_wp + 1;
                  end if;


         end case;
      end if;
   end process;

   request_record_cam : entity work.request_record_cam
   port map(
      addra   =>  s_rrcam_addra,
      addrb   =>  s_rrcam_addrb,
      clka    =>  s_rrcam_clka,
      clkb    =>  s_rrcam_clkb,
      dina    =>  s_rrcam_dina,
      doutb   =>  s_rrcam_doutb,
      enb     =>  s_rrcam_enb,
      wea     =>  s_rrcam_wea
   );

end architecture;
