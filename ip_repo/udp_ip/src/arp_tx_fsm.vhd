library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity arp_tx_fsm is
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
end arp_tx_fsm;

architecture Behavioral of arp_tx_fsm is

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

    signal crc_rst     : std_logic;
    signal crc_en      : std_logic;
    signal crc_out     : std_logic_vector(31 downto 0);
    signal tx_data_int : std_logic_vector(7 downto 0) := x"00";

    type header_rom_t is array (0 to 41) of std_logic_vector(7 downto 0);
    constant TX_HEADERS : header_rom_t := (
        -- 1. Ethernet Header (14 Bytes)
        x"00", x"00", x"00", x"00", x"00", x"00", -- [0-5]   Dest MAC (Dynamic Placeholder)
        x"00", x"18", x"3E", x"04", x"F7", x"0A", -- [6-11]  Src MAC  (FPGA MAC)
        x"08", x"06",                             -- [12-13] EtherType (ARP = x"0806")
        
        -- 2. ARP Payload (28 Bytes)
        x"00", x"01",                             -- [14-15] HW Type (Ethernet)
        x"08", x"00",                             -- [16-17] Protocol Type (IPv4)
        x"06",                                    -- [18]    HW Size (6 bytes for MAC)
        x"04",                                    -- [19]    Protocol Size (4 bytes for IP)
        x"00", x"02",                             -- [20-21] Opcode (Reply = x"0002")
        x"00", x"18", x"3E", x"04", x"F7", x"0A", -- [22-27] Sender MAC (FPGA MAC)
        x"0A", x"00", x"00", x"02",               -- [28-31] Sender IP  (FPGA IP: 10.0.0.2)
        x"00", x"00", x"00", x"00", x"00", x"00", -- [32-37] Target MAC (Dynamic Placeholder)
        x"00", x"00", x"00", x"00"                -- [38-41] Target IP  (Dynamic Placeholder)
    );

    type state_t is (IDLE, WAIT_MAC, SEND_HEADER, SEND_PADDING, SEND_FCS);
    signal state : state_t := IDLE;
    
    signal byte_count      : integer := 0;
    signal pending_trigger : std_logic := '0';

    type mac_arr is array(0 to 5) of std_logic_vector(7 downto 0);
    type ip_arr is array(0 to 3) of std_logic_vector(7 downto 0);
    
    signal current_dest_mac : mac_arr;
    signal current_dest_ip  : ip_arr;

begin

    current_dest_mac(0) <= dest_mac(47 downto 40);
    current_dest_mac(1) <= dest_mac(39 downto 32);
    current_dest_mac(2) <= dest_mac(31 downto 24);
    current_dest_mac(3) <= dest_mac(23 downto 16);
    current_dest_mac(4) <= dest_mac(15 downto 8);
    current_dest_mac(5) <= dest_mac(7 downto 0);

    current_dest_ip(0)  <= dest_ip(31 downto 24);
    current_dest_ip(1)  <= dest_ip(23 downto 16);
    current_dest_ip(2)  <= dest_ip(15 downto 8);
    current_dest_ip(3)  <= dest_ip(7 downto 0);

    crc_rst <= '1' when state = IDLE else '0';
    crc_en  <= mac_tx_advance when (state = SEND_HEADER or state = SEND_PADDING) else '0';

    crc_checker : ethernet_crc32 port map(
        clk         => sample_clk,
        reset       => crc_rst,
        enable      => crc_en,
        data_in     => tx_data_int,
        crc_out     => crc_out, 
        packet_good => open
    );

    mac_tx_data <= crc_out(7 downto 0)   when state = SEND_FCS and byte_count = 1 else
                   crc_out(15 downto 8)  when state = SEND_FCS and byte_count = 2 else
                   crc_out(23 downto 16) when state = SEND_FCS and byte_count = 3 else
                   crc_out(31 downto 24) when state = SEND_FCS and byte_count = 4 else
                   tx_data_int;

    process(sample_clk)
    begin
        if rising_edge(sample_clk) then
            if reset = '1' then
                state <= IDLE;
                byte_count <= 0;
                mac_tx_request <= '0';
                mac_tx_valid <= '0';
                mac_tx_last <= '0';
                tx_data_int <= x"00";
                pending_trigger <= '0';
            else
                if arp_trigger = '1' then
                    pending_trigger <= '1';
                end if;

                case state is
                    when IDLE =>
                        mac_tx_request <= '0';
                        mac_tx_valid   <= '0';
                        mac_tx_last    <= '0';
                        if arp_trigger = '1' or pending_trigger = '1' then
                            state <= WAIT_MAC;
                            mac_tx_request <= '1'; 
                            pending_trigger <= '0';
                        end if;

                    when WAIT_MAC =>
                        if mac_tx_grant = '1' and mac_tx_advance = '1' then
                            state <= SEND_HEADER;
                            byte_count <= 1; 
                            tx_data_int <= current_dest_mac(0);
                            mac_tx_valid <= '1';
                        end if;

                    when SEND_HEADER =>
                        if mac_tx_advance = '1' then
                            if byte_count = 42 then
                                state <= SEND_PADDING;
                                byte_count <= 1;
                                tx_data_int <= x"00"; 
                            else
                                if byte_count >= 0 and byte_count <= 5 then
                                    tx_data_int <= current_dest_mac(byte_count);
                                elsif byte_count >= 32 and byte_count <= 37 then
                                    tx_data_int <= current_dest_mac(byte_count - 32);
                                elsif byte_count >= 38 and byte_count <= 41 then
                                    tx_data_int <= current_dest_ip(byte_count - 38);
                                else
                                    tx_data_int <= TX_HEADERS(byte_count);
                                end if;
                                
                                byte_count <= byte_count + 1;
                            end if;
                        end if;

                    when SEND_PADDING =>
                        if mac_tx_advance = '1' then
                            if byte_count = 18 then
                                state <= SEND_FCS;
                                byte_count <= 1;
                            else
                                tx_data_int <= x"00";
                                byte_count <= byte_count + 1;
                            end if;
                        end if;

                    when SEND_FCS =>
                        if mac_tx_advance = '1' then
                            if byte_count = 1 then
                                byte_count <= 2;
                            elsif byte_count = 2 then
                                byte_count <= 3;
                            elsif byte_count = 3 then
                                byte_count <= 4; 
                            elsif byte_count = 4 then
                                mac_tx_last <= '1'; 
                                state <= IDLE;
                            end if;
                        end if;

                end case;
            end if;
        end if;
    end process;

end Behavioral;