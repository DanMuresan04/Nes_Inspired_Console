library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity udp_rx_fsm is
    Port (
        sample_clk       : in  std_logic;
        reset            : in  std_logic; 

        mac_data         : in  std_logic_vector(7 downto 0);
        mac_valid        : in  std_logic;
        mac_frame_active : in  std_logic;
        mac_rxerr        : in  std_logic;
        
        -- AXI4-Stream Data (To Main Xilinx Data FIFO)
        m_axis_tdata     : out std_logic_vector(7 downto 0);
        m_axis_tvalid    : out std_logic;
        m_axis_tlast     : out std_logic;
        
        -- Metadata (To Small 1-bit Xilinx FIFO)
        meta_data        : out std_logic;
        meta_wen         : out std_logic;
        
        trigger_ack_out  : out std_logic;
        ack_seq_out      : out std_logic_vector(15 downto 0)
    );
end udp_rx_fsm;

architecture Behavioral of udp_rx_fsm is

    component ethernet_crc32 is
    Port (
        clk         : in  std_logic;
        reset       : in  std_logic; 
        enable      : in  std_logic;
        data_in     : in  std_logic_vector(7 downto 0);
        crc_out     : out std_logic_vector(31 downto 0);
        packet_good : out std_logic
    );
    end component;
    
    type mac_arr is array(0 to 5) of std_logic_vector(7 downto 0);
    constant MAC_ADDR   : mac_arr := (x"00", x"18", x"3E", x"04", x"F7", x"0A");
    
    type eth_arr is array(0 to 1) of std_logic_vector(7 downto 0);
    constant ETHER_TYPE : eth_arr := (x"08", x"00");
    
    constant VER_IHL    : std_logic_vector(7 downto 0)  := x"45";
    constant PROTOCOL   : std_logic_vector(7 downto 0)  := x"11";
    
    type ip_arr is array(0 to 3) of std_logic_vector(7 downto 0);
    constant FPGA_IP    : ip_arr := (x"0A", x"00", x"00", x"02");
    
    type port_arr is array(0 to 1) of std_logic_vector(7 downto 0);
    constant FPGA_PORT  : port_arr := (x"30", x"39");
    
    signal packet_length : std_logic_vector(15 downto 0) := x"0000";
    signal rx_seq        : std_logic_vector(15 downto 0) := x"0000";
    signal expected_seq  : unsigned(15 downto 0) := x"0000";
    
    signal trigger_ack   : std_logic := '0';

    type state_t is (IDLE, CHECK_MAC, CHECK_HEADERS, PARSE_DATA, WAIT_END, VALIDATE_CRC, DROP_FRAME);
    signal state : state_t := IDLE;

    signal byte_count : integer := 0;

    signal crc_rst     : std_logic;
    signal crc_en      : std_logic;
    signal crc_out     : std_logic_vector(31 downto 0);
    signal packet_good : std_logic;
    
    -- New Signals for FIFO Synchronization
    signal fifo_writing : std_logic := '0';
    signal meta_pending : std_logic := '0';

begin
    trigger_ack_out <= trigger_ack;
    ack_seq_out     <= rx_seq; 
    
    crc_rst <= '1' when (mac_frame_active = '0' and state = IDLE) or reset = '1' else '0';
    crc_en  <= '1' when (state = IDLE or state = CHECK_MAC or state = CHECK_HEADERS or state = PARSE_DATA or state = WAIT_END) and mac_valid = '1' else '0';
    
    checker : ethernet_crc32 port map(
        clk         => sample_clk,
        reset       => crc_rst,
        enable      => crc_en,
        data_in     => mac_data,
        crc_out     => crc_out,
        packet_good => packet_good
    );

    process(sample_clk)
    begin
        if rising_edge(sample_clk) then
            if reset = '1' then
                state <= IDLE;
                byte_count <= 0;
                expected_seq <= x"0000";
                trigger_ack <= '0';
                
                m_axis_tvalid <= '0';
                m_axis_tlast  <= '0';
                meta_wen      <= '0';
                fifo_writing  <= '0';
                meta_pending  <= '0';
            else
                -- Default assignments ensure pulses only last for 1 clock cycle
                trigger_ack   <= '0';
                m_axis_tvalid <= '0';
                m_axis_tlast  <= '0';
                meta_wen      <= '0';
                
                if state = VALIDATE_CRC then
                    if meta_pending = '1' then
                        meta_wen <= '1'; -- Write the flag to the metadata FIFO
                        
                        -- Check CRC AND Sequence Number Check
                        if packet_good = '1' and unsigned(rx_seq) = expected_seq then
                            meta_data <= '1'; -- GOOD packet flag
                            expected_seq <= expected_seq + 1;
                            trigger_ack  <= '1';
                        else
                            meta_data <= '0'; -- BAD packet flag (CRC fail or out of order)
                        end if;
                        meta_pending <= '0';
                    end if;
                    state <= IDLE;

                elsif mac_frame_active = '0' or mac_rxerr = '1' then
                    if fifo_writing = '1' then
                        -- DANGER: Frame dropped mid-payload. The main FIFO is open and waiting!
                        -- Force close the AXI stream with dummy data and a TLAST to seal it.
                        m_axis_tdata  <= x"00";
                        m_axis_tvalid <= '1';
                        m_axis_tlast  <= '1';
                        fifo_writing  <= '0';
                        meta_pending  <= '1'; -- We must go write a BAD metadata flag next cycle
                        state <= VALIDATE_CRC;
                    elsif meta_pending = '1' then
                        -- Normal end of frame, waiting to validate
                        state <= VALIDATE_CRC;
                    else
                        -- Frame dropped during headers, nothing was ever written to FIFO
                        state <= IDLE;
                    end if;
                    byte_count <= 0;
                    
                elsif mac_valid = '1' then
                    case state is
                        when IDLE =>
                            if mac_data = MAC_ADDR(0) then
                                state <= CHECK_MAC;
                                byte_count <= 1;
                            else
                                state <= DROP_FRAME;
                            end if;

                        when CHECK_MAC =>
                            if mac_data /= MAC_ADDR(byte_count) then
                                state <= DROP_FRAME;
                            elsif byte_count = 5 then
                                state <= CHECK_HEADERS;
                            end if;
                            byte_count <= byte_count + 1;

                        when CHECK_HEADERS =>
                            case byte_count is
                                when 12 to 13 => if mac_data /= ETHER_TYPE(byte_count - 12) then state <= DROP_FRAME; end if;
                                when 14 =>       if mac_data /= VER_IHL then state <= DROP_FRAME; end if;
                                when 23 =>       if mac_data /= PROTOCOL then state <= DROP_FRAME; end if;
                                when 30 to 33 => if mac_data /= FPGA_IP(byte_count - 30) then state <= DROP_FRAME; end if;
                                when 36 to 37 => if mac_data /= FPGA_PORT(byte_count - 36) then state <= DROP_FRAME; end if;
                                when 38 =>       packet_length(15 downto 8) <= mac_data;
                                when 39 =>       packet_length(7 downto 0)  <= mac_data;
                                when 42 =>       rx_seq(15 downto 8) <= mac_data;
                                when 43 =>       
                                    rx_seq(7 downto 0) <= mac_data;
                                    state <= PARSE_DATA;
                                when others => null;
                            end case;
                            byte_count <= byte_count + 1;
                            
                        when PARSE_DATA =>
                            -- Route payload directly out to AXI Stream Main FIFO
                            m_axis_tdata  <= mac_data;
                            m_axis_tvalid <= '1';
                            
                            if byte_count >= to_integer(unsigned(packet_length)) + 33 then
                                m_axis_tlast <= '1'; -- Flag end of packet for AXI Stream
                                fifo_writing <= '0';
                                meta_pending <= '1'; -- Tell the FSM to write metadata when frame ends
                                state <= WAIT_END;
                            else
                                fifo_writing <= '1'; -- We are actively writing a packet
                            end if;
                            byte_count <= byte_count + 1;

                        when WAIT_END =>
                            byte_count <= byte_count + 1;
                            
                        when VALIDATE_CRC =>
                            null; 
                            
                        when DROP_FRAME =>
                            null; 
                            
                    end case;
                end if;
            end if;
        end if;
    end process;

end Behavioral;