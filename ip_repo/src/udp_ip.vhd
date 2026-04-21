library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity udp_ip is
    Port (
        clk_ref_internal  : in std_logic;
        clk_skew_internal : in std_logic;
        locked            : in std_logic;
       
        resetn         : in std_logic;  
         
        ETH_REFCLK     : out std_logic;
        ETH_RSTN       : out std_logic;
        ETH_CRSDV      : in std_logic;
        ETH_RXERR      : in std_logic;
        ETH_RXD        : in std_logic_vector(1 downto 0);
        ETH_TXEN       : out std_logic;
        ETH_TXD        : out std_logic_vector(1 downto 0)
    );
end udp_ip;

architecture Behavioral of udp_ip is

    component udp_rx_fsm is
    Port (
        sample_clk       : in  std_logic;
        reset            : in  std_logic;
        mac_data         : in  std_logic_vector(7 downto 0);
        mac_valid        : in  std_logic;
        mac_frame_active : in  std_logic;
        mac_rxerr        : in  std_logic;
        trigger_ack_out  : out std_logic;
        ack_seq_out      : out std_logic_vector(15 downto 0)
    );
    end component;

    component udp_tx_fsm is
    Port (
        sample_clk      : in  std_logic;
        reset           : in  std_logic;
        
        -- New Dynamic Bus Inputs
        dest_mac        : in  std_logic_vector(47 downto 0);
        dest_ip         : in  std_logic_vector(31 downto 0);
        
        trigger_ack     : in  std_logic;
        ack_seq         : in  std_logic_vector(15 downto 0);
        
        mac_tx_request  : out std_logic;
        mac_tx_grant    : in  std_logic;
        mac_tx_data     : out std_logic_vector(7 downto 0);
        mac_tx_valid    : out std_logic;
        mac_tx_last     : out std_logic;
        mac_tx_advance  : in  std_logic
    );
    end component;
    
    component arp_fsm is
    Port (
        sample_clk          : in  std_logic;
        reset               : in  std_logic; 
        
        mac_rx_data         : in  std_logic_vector(7 downto 0);
        mac_rx_valid        : in  std_logic;
        mac_rx_frame_active : in  std_logic;
        mac_rx_rxerr        : in  std_logic;
        
        arp_mac_out         : out std_logic_vector(47 downto 0);
        arp_ip_out          : out std_logic_vector(31 downto 0);
        arp_ready           : out std_logic
    );
    end component;

    component arp_tx_fsm is
    Port (
        sample_clk      : in  std_logic;
        reset           : in  std_logic;
        
        dest_mac        : in  std_logic_vector(47 downto 0);
        dest_ip         : in  std_logic_vector(31 downto 0);
        
        arp_trigger     : in  std_logic;
        
        mac_tx_request  : out std_logic;
        mac_tx_grant    : in  std_logic;
        mac_tx_data     : out std_logic_vector(7 downto 0);
        mac_tx_valid    : out std_logic;
        mac_tx_last     : out std_logic;
        mac_tx_advance  : in  std_logic  
    );
    end component;

    --reset
    signal sys_rst              : std_logic;
    
    signal internal_trigger_ack : std_logic := '0';
    signal internal_ack_seq     : std_logic_vector(15 downto 0);

    -- THE GLOBAL CONFIGURATION BUS (Initialized to your PC's defaults to prevent startup drops)
    signal global_arp_ready : std_logic;
    signal dynamic_pc_mac   : std_logic_vector(47 downto 0) := x"00183E04F70A"; 
    signal dynamic_pc_ip    : std_logic_vector(31 downto 0) := x"0A000001";

    -- Debug Latches
    signal dbg_arp_ready_latch : std_logic := '0';
    signal dbg_arp_mac_latch   : std_logic := '0';
    signal dbg_arp_ip_latch    : std_logic := '0';

    -- RX Signals
    signal crsdv_sync, rxd_sync_0, rxd_sync_1, rxerr_sync : std_logic_vector(1 downto 0) := "00";
    signal crsdv_s, rxerr_s  : std_logic;
    signal rxd_s             : std_logic_vector(1 downto 0);
    signal rx_shift_reg      : std_logic_vector(7 downto 0) := (others => '0');
    signal mac_rx_data       : std_logic_vector(7 downto 0) := (others => '0');
    signal mac_rx_valid      : std_logic := '0';
    signal mac_frame_active  : std_logic := '0';

    -- UDP TX Signals
    signal udp_tx_req, udp_tx_valid, udp_tx_last : std_logic;
    signal udp_tx_data : std_logic_vector(7 downto 0);
    signal udp_tx_grant   : std_logic := '0';
    signal udp_tx_advance : std_logic := '0';
    
    -- ARP TX Signals
    signal arp_tx_req, arp_tx_valid, arp_tx_last : std_logic;
    signal arp_tx_data : std_logic_vector(7 downto 0);
    signal arp_tx_grant   : std_logic := '0';
    signal arp_tx_advance : std_logic := '0';
    
    -- TX Arbiter Multiplexed Signals
    signal active_tx_source : std_logic := '0'; -- '0' = UDP, '1' = ARP
    signal current_tx_data  : std_logic_vector(7 downto 0);
    signal current_tx_last  : std_logic;
    signal mac_tx_advance   : std_logic := '0';
    
    type tx_mac_state_t is (IDLE, PREAMBLE, SFD, TX_DATA, IPG);
    signal tx_mac_state : tx_mac_state_t := IDLE;
    
    signal tx_bit_cnt   : unsigned(1 downto 0) := "00";
    signal tx_byte_cnt  : integer := 0;
    signal tx_byte      : std_logic_vector(7 downto 0) := x"00";



begin

    ETH_REFCLK <= clk_ref_internal;
    ETH_RSTN   <= resetn and locked;
    sys_rst    <= (not resetn) or (not locked); 


    -- RX Serializer
    process(clk_skew_internal)
    begin
        if rising_edge(clk_skew_internal) then
            crsdv_sync(0) <= ETH_CRSDV; rxd_sync_0 <= ETH_RXD; rxerr_sync(0) <= ETH_RXERR;
            crsdv_sync(1) <= crsdv_sync(0); rxd_sync_1 <= rxd_sync_0; rxerr_sync(1) <= rxerr_sync(0);
        end if;
    end process;
    crsdv_s <= crsdv_sync(1); rxd_s <= rxd_sync_1; rxerr_s <= rxerr_sync(1);

    process(clk_skew_internal)
        variable bit_count : unsigned(1 downto 0) := "00";
    begin
        if rising_edge(clk_skew_internal) then
            mac_rx_valid <= '0';
            if sys_rst = '1' then
                mac_frame_active <= '0';
                bit_count := "00";
            elsif crsdv_s = '1' then
                rx_shift_reg <= rxd_s & rx_shift_reg(7 downto 2);
                if mac_frame_active = '0' then
                    if (rxd_s & rx_shift_reg(7 downto 2)) = x"D5" then
                        bit_count := "11";
                        mac_frame_active <= '1';
                    end if;
                else
                    if bit_count = "11" then
                        mac_rx_data  <= rxd_s & rx_shift_reg(7 downto 2);
                        mac_rx_valid <= '1';
                    end if;
                end if;
                bit_count := bit_count + 1;
            else
                bit_count := "00";
                mac_frame_active <= '0';
            end if;
        end if;
    end process;

    rx_path : udp_rx_fsm port map (
        sample_clk => clk_skew_internal, 
        reset => sys_rst,
        mac_data => mac_rx_data, 
        mac_valid => mac_rx_valid,
        mac_frame_active => mac_frame_active, 
        mac_rxerr => rxerr_s,
        trigger_ack_out => internal_trigger_ack, 
        ack_seq_out => internal_ack_seq
    );

    arp_rx_path : arp_fsm port map (
        sample_clk          => clk_skew_internal,
        reset               => sys_rst,
        mac_rx_data         => mac_rx_data,
        mac_rx_valid        => mac_rx_valid,
        mac_rx_frame_active => mac_frame_active,
        mac_rx_rxerr        => rxerr_s,
        
        arp_mac_out         => dynamic_pc_mac,
        arp_ip_out          => dynamic_pc_ip,
        arp_ready           => global_arp_ready
    );

    


   -- Updated TX Serializer with Early-Pulse Timing & Arbiter
    process(clk_skew_internal)
    begin
        if rising_edge(clk_skew_internal) then
            if sys_rst = '1' then
                tx_mac_state <= IDLE;
                tx_bit_cnt   <= "00";
                udp_tx_grant <= '0';
                arp_tx_grant <= '0';
                mac_tx_advance <= '0';
                dbg_arp_ready_latch <= '0';
                dbg_arp_mac_latch   <= '0';
                dbg_arp_ip_latch    <= '0';
            else
                mac_tx_advance <= '0'; 

                case tx_mac_state is
                    when IDLE =>
                        tx_bit_cnt   <= "00";
                        tx_byte_cnt  <= 0;
                        udp_tx_grant <= '0';
                        arp_tx_grant <= '0';
                        
                        -- Priority Arbitration
                        if arp_tx_req = '1' then
                            tx_mac_state <= PREAMBLE;
                            arp_tx_grant <= '1';
                            active_tx_source <= '1';
                            tx_byte      <= x"55";
                        elsif udp_tx_req = '1' then
                            tx_mac_state <= PREAMBLE;
                            udp_tx_grant <= '1';
                            active_tx_source <= '0';
                            tx_byte      <= x"55";
                        end if;

                    when PREAMBLE =>
                        tx_bit_cnt <= tx_bit_cnt + 1;
                        if tx_bit_cnt = "11" then
                            if tx_byte_cnt = 6 then
                                tx_mac_state <= SFD;
                                tx_byte      <= x"D5";
                                tx_byte_cnt  <= 0;
                            else
                                tx_byte_cnt  <= tx_byte_cnt + 1;
                            end if;
                        end if;

                    when SFD =>
                        tx_bit_cnt <= tx_bit_cnt + 1;
                        if tx_bit_cnt = "01" then
                            mac_tx_advance <= '1';
                        end if;
                        if tx_bit_cnt = "11" then
                            tx_mac_state <= TX_DATA;
                            -- Pull data from the actively granted FSM
                            tx_byte      <= current_tx_data; 
                        end if;

                    when TX_DATA =>
                        tx_bit_cnt <= tx_bit_cnt + 1;
                        if tx_bit_cnt = "01" then
                            if current_tx_last = '0' then
                                mac_tx_advance <= '1';
                            end if;
                        end if;
                        if tx_bit_cnt = "11" then
                            if current_tx_last = '1' then
                                tx_mac_state <= IPG;
                                tx_byte_cnt  <= 0;
                            else
                                tx_byte <= current_tx_data;
                            end if;
                        end if;

                    when IPG =>
                        udp_tx_grant <= '0'; 
                        arp_tx_grant <= '0';
                        tx_bit_cnt <= tx_bit_cnt + 1;
                        if tx_bit_cnt = "11" then
                            if tx_byte_cnt = 11 then
                                tx_mac_state <= IDLE;
                            else
                                tx_byte_cnt <= tx_byte_cnt + 1;
                            end if;
                        end if;
                end case;

                if tx_mac_state = PREAMBLE or tx_mac_state = SFD or tx_mac_state = TX_DATA then
                    ETH_TXEN <= '1';
                else
                    ETH_TXEN <= '0';
                end if;
                
                case tx_bit_cnt is
                    when "00" => ETH_TXD <= tx_byte(1 downto 0);
                    when "01" => ETH_TXD <= tx_byte(3 downto 2);
                    when "10" => ETH_TXD <= tx_byte(5 downto 4);
                    when "11" => ETH_TXD <= tx_byte(7 downto 6);
                    when others => ETH_TXD <= "00";
                end case;
            end if;
        end if;
    end process;

  
    current_tx_data <= arp_tx_data when active_tx_source = '1' else udp_tx_data;
    current_tx_last <= arp_tx_last when active_tx_source = '1' else udp_tx_last;
    
    arp_tx_advance  <= mac_tx_advance when active_tx_source = '1' else '0';
    udp_tx_advance  <= mac_tx_advance when active_tx_source = '0' else '0';


    -- =========================================================
    -- FSM Instantiations
    -- =========================================================
    udp_tx_path : udp_tx_fsm port map (
         sample_clk => clk_skew_internal, 
         reset => sys_rst,
         
         dest_mac => dynamic_pc_mac,
         dest_ip  => dynamic_pc_ip,
         
         trigger_ack => internal_trigger_ack, 
         ack_seq => internal_ack_seq,
         
         mac_tx_request => udp_tx_req,
         mac_tx_grant   => udp_tx_grant,
         mac_tx_data    => udp_tx_data,
         mac_tx_valid   => udp_tx_valid,
         mac_tx_last    => udp_tx_last,
         mac_tx_advance => udp_tx_advance
     );

    arp_tx_path : arp_tx_fsm port map (
         sample_clk => clk_skew_internal, 
         reset => sys_rst,
         
         dest_mac => dynamic_pc_mac,
         dest_ip  => dynamic_pc_ip,
         
         arp_trigger => global_arp_ready,
         
         mac_tx_request => arp_tx_req,
         mac_tx_grant   => arp_tx_grant,
         mac_tx_data    => arp_tx_data,
         mac_tx_valid   => arp_tx_valid,
         mac_tx_last    => arp_tx_last,
         mac_tx_advance => arp_tx_advance
    );

end Behavioral;