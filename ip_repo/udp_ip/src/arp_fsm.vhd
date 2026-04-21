----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/10/2026 08:13:48 PM
-- Design Name: 
-- Module Name: arp_rx_fsm - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity arp_fsm is
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
end arp_fsm;

architecture Behavioral of arp_fsm is   

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

    -- Constant Arrays
    type mac_arr is array(0 to 5) of std_logic_vector(7 downto 0);
    constant BROADCAST_MAC  : mac_arr := (x"FF", x"FF", x"FF", x"FF", x"FF", x"FF");
    
    type eth_arr is array(0 to 1) of std_logic_vector(7 downto 0);
    constant ARP_ETHER_TYPE : eth_arr := (x"08", x"06");
    constant HW_TYPE        : eth_arr := (x"00", x"01");
    constant PROTO_TYPE     : eth_arr := (x"08", x"00");
    constant OPCODE_REQ     : eth_arr := (x"00", x"01");
    
    constant HW_LEN         : std_logic_vector(7 downto 0)  := x"06";
    constant PROTO_LEN      : std_logic_vector(7 downto 0)  := x"04";
    
    type ip_arr is array(0 to 3) of std_logic_vector(7 downto 0);
    constant FPGA_IP        : ip_arr := (x"0A", x"00", x"00", x"02");
    
    signal latched_pc_mac   : mac_arr;
    signal latched_pc_ip    : ip_arr;
    
    type state_t is (IDLE, CHECK_MAC, CHECK_HEADERS, WAIT_END, VALIDATE_CRC, DROP_FRAME);
    signal state : state_t := IDLE;
    signal byte_count : integer := 0;
    
    -- Internal CRC Signals
    signal crc_rst              : std_logic;
    signal crc_en               : std_logic;
    signal internal_packet_good : std_logic;
     
begin

    -- Internal CRC Wiring
    crc_rst <= '1' when (mac_rx_frame_active = '0' and state = IDLE) or reset = '1' else '0';
    crc_en  <= '1' when mac_rx_valid = '1' else '0';

    crc_checker : ethernet_crc32 port map(
        clk         => sample_clk,
        reset       => crc_rst,
        enable      => crc_en,
        data_in     => mac_rx_data,
        crc_out     => open, 
        packet_good => internal_packet_good
    );

    process(sample_clk)
    begin
        if rising_edge(sample_clk) then
            if reset = '1' then
                state <= IDLE;
                byte_count <= 0;
                arp_ready <= '0';
            else
                arp_ready <= '0';
                
                if state = VALIDATE_CRC then
                    if internal_packet_good = '1' then
                        arp_ready  <= '1';
                    end if;
                    state <= IDLE;

                elsif mac_rx_frame_active = '0' or mac_rx_rxerr = '1' then
                    if state = WAIT_END then
                        state <= VALIDATE_CRC;
                    else
                        state <= IDLE;
                    end if;
                    byte_count <= 0;
                    
                elsif mac_rx_valid = '1' then
                    case state is
                        when IDLE =>
                            if mac_rx_data = BROADCAST_MAC(0) then
                                state <= CHECK_MAC;
                                byte_count <= 1;
                            else
                                state <= DROP_FRAME;
                            end if;

                        when CHECK_MAC =>
                            if mac_rx_data /= BROADCAST_MAC(byte_count) then
                                state <= DROP_FRAME;
                            elsif byte_count = 5 then
                                state <= CHECK_HEADERS;
                            end if;
                            byte_count <= byte_count + 1;

                        when CHECK_HEADERS =>
                            case byte_count is
                                when 12 to 13 => if mac_rx_data /= ARP_ETHER_TYPE(byte_count - 12) then state <= DROP_FRAME; end if;
                                when 14 to 15 => if mac_rx_data /= HW_TYPE(byte_count - 14)        then state <= DROP_FRAME; end if;
                                when 16 to 17 => if mac_rx_data /= PROTO_TYPE(byte_count - 16)     then state <= DROP_FRAME; end if;
                                when 18 =>       if mac_rx_data /= HW_LEN                          then state <= DROP_FRAME; end if;
                                when 19 =>       if mac_rx_data /= PROTO_LEN                       then state <= DROP_FRAME; end if;
                                when 20 to 21 => if mac_rx_data /= OPCODE_REQ(byte_count - 20)     then state <= DROP_FRAME; end if;
                                
                                when 22 to 27 => latched_pc_mac(byte_count - 22) <= mac_rx_data;
                                when 28 to 31 => latched_pc_ip(byte_count - 28)  <= mac_rx_data;
                                
                                when 38 to 41 => 
                                    if mac_rx_data /= FPGA_IP(byte_count - 38) then 
                                        state <= DROP_FRAME; 
                                    end if;
                                    
                                    if byte_count = 41 then
                                        state <= WAIT_END;
                                    end if;
                                    
                                when others => null;
                            end case;
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

    arp_mac_out <= latched_pc_mac(0) & latched_pc_mac(1) & latched_pc_mac(2) & 
                   latched_pc_mac(3) & latched_pc_mac(4) & latched_pc_mac(5);
                   
    arp_ip_out  <= latched_pc_ip(0) & latched_pc_ip(1) & 
                   latched_pc_ip(2) & latched_pc_ip(3);

end Behavioral;