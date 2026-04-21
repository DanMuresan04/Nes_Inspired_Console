----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03/16/2026 09:53:07 PM
-- Design Name: 
-- Module Name: axi_lite_slave - Behavioral
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

------------------------------------------------------------------------------------


                    -- CURRENT REGISTER MAP READ BEFORE CHANGE:
                    --REGISTER 0  READ ONLY : COLLISION FLAGS LOW 32
                    --REGISTER 1  READ ONLY : COLLISION FLAGS HIGH 32
                    --REGISTER 3  READ ONLY : KEY FLAGS FROM CONTROLLER
                    --REGISTER 4  READ ONLY : VGA VERT SYNC PULSE 
                   
                    --  WRITE REGISTERS
                    -- REGISTER 2 WRITE : SCROLL X AND SCROLL Y 
                    -- REGISTER 5 WRITE : CPU WRITE SPRITES TO BRAM ON PROGRAM LOAD 
                    
                    --  AVAILABLE REGISTERS
                    -- REGISTER 8
                    -- REGISTER 7
                    -- REGISTER 6
---------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;


entity axi_lite_slave is
  Generic(
        c_s_axi_data_width : integer := 32;
        c_s_axi_addr_width : integer := 32
  );
  Port ( 
        s_axi_aclk    : in std_logic;
        s_axi_aresetn : in std_logic;
        
        s_axi_awaddr  : in std_logic_vector(c_s_axi_addr_width - 1 downto 0);
        s_axi_awvalid : in std_logic;
        s_axi_awready : out std_logic;
        
        s_axi_wdata   : in std_logic_vector(c_s_axi_data_width - 1 downto 0);
        s_axi_wstrb   : in std_logic_vector(c_s_axi_data_width / 8 - 1 downto 0); 
        s_axi_wvalid  : in std_logic;
        s_axi_wready  : out std_logic;
        
        s_axi_bresp   : out std_logic_vector(1 downto 0);
        s_axi_bvalid  : out std_logic;
        s_axi_bready  : in std_logic;
        
        s_axi_araddr  : in std_logic_vector(c_s_axi_addr_width - 1 downto 0);
        s_axi_arvalid : in std_logic;
        s_axi_arready : out std_logic;
        
        s_axi_rdata   : out std_logic_vector(c_s_axi_data_width - 1 downto 0);
        s_axi_rresp   : out std_logic_vector(1 downto 0);
        s_axi_rvalid  : out std_logic;
        s_axi_rready  : in std_logic;
        
        key_flags_in       : in std_logic_vector(7 downto 0);
        vga_vsync_in       : in std_logic;
        collision_flags_lo : in std_logic_vector(31 downto 0);
        collision_flags_hi : in std_logic_vector(31 downto 0);
        
        oam_we_o        : out std_logic;
        oam_addr_o      : out std_logic_vector(5 downto 0);
        oam_din_o       : out std_logic_vector(31 downto 0);
        
        vram_we_a_o     : out std_logic;
        vram_addr_a_o   : out std_logic_vector(10 downto 0);
        vram_din_a_o    : out std_logic_vector(7 downto 0);
        
        hud_char_we_o   : out std_logic;
        hud_char_addr_o : out std_logic_vector(8 downto 0);
        hud_char_din_o  : out std_logic_vector(7 downto 0);
        
        font_ram_we_o   : out std_logic;
        font_ram_addr_o : out std_logic_vector(8 downto 0);
        font_ram_din_o  : out std_logic_vector(8 downto 0);
        
        scroll_x_o      : out std_logic_vector(15 downto 0);
        scroll_y_o      : out std_logic_vector(15 downto 0);
     
        slv_reg5_data_o : out std_logic_vector(31 downto 0);
        slv_reg5_we_o   : out std_logic;
        
        cpu_selector_o  : out std_logic;
        
        ppu_irq        : out std_logic 
  );
end axi_lite_slave;

architecture Behavioral of axi_lite_slave is
    
    signal slv_reg0 : std_logic_vector(31 downto 0) := (others => '0');  
    signal slv_reg1 : std_logic_vector(31 downto 0) := (others => '0'); 
    signal slv_reg2 : std_logic_vector(31 downto 0) := (others => '0'); 
    signal slv_reg3 : std_logic_vector(31 downto 0) := (others => '0');
    signal slv_reg4 : std_logic_vector(31 downto 0) := (others => '0');
    signal slv_reg5 : std_logic_vector(31 downto 0) := (others => '0');
    signal slv_reg6 : std_logic_vector(31 downto 0) := (others => '0');
    signal slv_reg7 : std_logic_vector(31 downto 0) := (others => '0');
    
    signal axi_awready : std_logic := '0';
    signal axi_wready  : std_logic := '0';
    signal axi_bvalid  : std_logic := '0';
    signal axi_arready : std_logic := '0';
    signal axi_rvalid  : std_logic := '0';
    signal axi_rdata   : std_logic_vector(31 downto 0) := (others => '0');
    
begin
    
    s_axi_awready <= axi_awready;
    s_axi_wready  <= axi_wready;
    s_axi_bvalid  <= axi_bvalid;
    s_axi_bresp   <= "00";
    
    s_axi_arready <= axi_arready;
    s_axi_rvalid  <= axi_rvalid;
    s_axi_rdata   <= axi_rdata;
    s_axi_rresp   <= "00"; 
    
    scroll_x_o <= slv_reg2(15 downto 0);
    scroll_y_o <= slv_reg2(31 downto 16);
    
    slv_reg5_data_o <= slv_reg5;
    cpu_selector_o  <= slv_reg6(0);
    --write cpu to fpga
    write_channel : process(s_axi_aclk) 
        variable loc_addr : std_logic_vector(9 downto 0);
    begin
        if rising_edge(s_axi_aclk) then
            if s_axi_aresetn = '0' then
                axi_awready   <= '0';
                axi_wready    <= '0';
                axi_bvalid    <= '0';
                oam_we_o      <= '0';
                vram_we_a_o   <= '0';
                font_ram_we_o <= '0';
                hud_char_we_o <= '0';
                slv_reg5_we_o <= '0';
                slv_reg0    <= (others => '0');
                slv_reg1    <= (others => '0');
                slv_reg2    <= (others => '0');
                slv_reg3    <= (others => '0');
                slv_reg4    <= (others => '0');
                slv_reg5    <= (others => '0');
                slv_reg6    <= (others => '0');
                slv_reg7    <= (others => '0');
                
            else
                oam_we_o <= '0';
                hud_char_we_o <= '0'; 
                font_ram_we_o <= '0';
                slv_reg5_we_o <= '0';
                if axi_awready = '0' and axi_wready = '0' and s_axi_awvalid = '1' and s_axi_wvalid = '1' then -- data available
                    axi_awready <= '1';
                    axi_wready  <= '1';
                    
                    if s_axi_awaddr(11) = '1' then 
                        vram_we_a_o   <= '1';
                        
                        vram_addr_a_o <= s_axi_awaddr(10 downto 0);
                        
                        if s_axi_wstrb(0) = '1' then
                            vram_din_a_o <= s_axi_wdata(7 downto 0);
                        elsif s_axi_wstrb(1) = '1' then
                            vram_din_a_o <= s_axi_wdata(15 downto 8);
                        elsif s_axi_wstrb(2) = '1' then
                            vram_din_a_o <= s_axi_wdata(23 downto 16);
                        elsif s_axi_wstrb(3) = '1' then
                            vram_din_a_o <= s_axi_wdata(31 downto 24);
                        else
                            vram_din_a_o <= (others => '0');
                        end if;
                    else
                        loc_addr    := s_axi_awaddr(11 downto 2);
                        if unsigned(loc_addr) >= 64 and unsigned(loc_addr) < 128 then 
                            oam_we_o   <= '1';
                            oam_addr_o <= loc_addr(5 downto 0);
                            oam_din_o  <= s_axi_wdata; 
                            
                        elsif unsigned(loc_addr) >= 128 and unsigned(loc_addr) < 512 then
                            hud_char_we_o   <= '1';
                            hud_char_addr_o <= std_logic_vector(unsigned(loc_addr(8 downto 0)) - 128);
                            hud_char_din_o  <= s_axi_wdata(7 downto 0);
                            
                        elsif unsigned(loc_addr) >= 512 and unsigned(loc_addr) < 1024 then
                            font_ram_we_o   <= '1';
                            font_ram_addr_o <= loc_addr(8 downto 0); 
                            font_ram_din_o  <= s_axi_wdata(8 downto 0);
                                
                        elsif unsigned(loc_addr) < 8 then                      
                            case loc_addr(2 downto 0) is  -- decoder
                                when "000" =>
                                    for byte in 0 to 3 loop 
                                        if s_axi_wstrb(byte) = '1' then 
                                            slv_reg0((byte*8+7) downto (byte*8)) <= s_axi_wdata((byte*8+7) downto (byte*8));
                                        end if;
                                    end loop;
                                when "001" =>
                                    for byte in 0 to 3 loop 
                                        if s_axi_wstrb(byte) = '1' then 
                                            slv_reg1((byte*8+7) downto (byte*8)) <= s_axi_wdata((byte*8+7) downto (byte*8));
                                        end if;
                                    end loop;
                                when "010" =>
                                    for byte in 0 to 3 loop 
                                        if s_axi_wstrb(byte) = '1' then 
                                            slv_reg2((byte*8+7) downto (byte*8)) <= s_axi_wdata((byte*8+7) downto (byte*8));
                                        end if;
                                    end loop;    
                                 when "011" =>
                                    for byte in 0 to 3 loop 
                                        if s_axi_wstrb(byte) = '1' then 
                                            slv_reg3((byte*8+7) downto (byte*8)) <= s_axi_wdata((byte*8+7) downto (byte*8));
                                        end if;
                                    end loop;
                                 when "100" =>
                                    for byte in 0 to 3 loop 
                                        if s_axi_wstrb(byte) = '1' then 
                                            slv_reg4((byte*8+7) downto (byte*8)) <= s_axi_wdata((byte*8+7) downto (byte*8));
                                        end if;
                                    end loop;
                                 when "101" =>
                                    for byte in 0 to 3 loop 
                                        if s_axi_wstrb(byte) = '1' then 
                                            slv_reg5((byte*8+7) downto (byte*8)) <= s_axi_wdata((byte*8+7) downto (byte*8));
                                        end if;
                                    end loop;
                                    slv_reg5_we_o <= '1';
                                    
                                 when "110" =>
                                    for byte in 0 to 3 loop 
                                        if s_axi_wstrb(byte) = '1' then 
                                            slv_reg6((byte*8+7) downto (byte*8)) <= s_axi_wdata((byte*8+7) downto (byte*8));
                                        end if;
                                    end loop;
                                 when "111" =>
                                    for byte in 0 to 3 loop 
                                        if s_axi_wstrb(byte) = '1' then 
                                            slv_reg7((byte*8+7) downto (byte*8)) <= s_axi_wdata((byte*8+7) downto (byte*8));
                                        end if;
                                    end loop;
                                 when others => null;                    
                            end case;
                         end if;
                      end if;
                else
                    axi_awready <= '0';
                    axi_wready  <= '0';        
                end if;
                
                if axi_awready = '1' and axi_wready = '1' and axi_bvalid = '0' then
                    axi_bvalid <= '1';
                elsif s_axi_bready = '1' and axi_bvalid = '1' then
                    axi_bvalid <= '0';
                end if;
                
            end if;
        end if;
    end process;
    
    --read cpu from fpga
    read_channel : process(s_axi_aclk)
        variable loc_addr : std_logic_vector(2 downto 0);
    begin
        if rising_edge(s_axi_aclk) then
            if s_axi_aresetn = '0' then 
                axi_arready <= '0';
                axi_rvalid  <= '0';
            else
                if s_axi_arvalid = '1' and axi_arready = '0' then
                    axi_arready <= '1';
                    loc_addr    := s_axi_araddr(4 downto 2);
                    
                    case loc_addr is
                        when "000" => axi_rdata <= collision_flags_lo;
                        when "001" => axi_rdata <= collision_flags_hi; 
                        when "010" => axi_rdata <= slv_reg2;
                        when "011" => 
                            axi_rdata(31 downto 8) <= (others => '0'); 
                            axi_rdata(7 downto 0)  <= key_flags_in;
                        when "100" => 
                            axi_rdata(31 downto 1) <= (others => '0');
                            axi_rdata(0)           <= vga_vsync_in;
                        when "101" => axi_rdata <= slv_reg5;
                        when "110" => axi_rdata <= slv_reg6;
                        when "111" => axi_rdata <= slv_reg7;
                        when others => axi_rdata <= (others => '0');
                    end case;
                
                else 
                    axi_arready <= '0';
                end if; 
                
                if axi_arready = '1' and axi_rvalid = '0' then
                    axi_rvalid <= '1';
                elsif s_axi_rready = '1' and axi_rvalid = '1' then
                    axi_rvalid <= '0';
                end if;
            end if;
        end if;
    end process;
    
end Behavioral;
