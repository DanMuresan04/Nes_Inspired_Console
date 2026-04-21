library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sprite_renderer is
   Port(
        mem_write_clk  : in std_logic;
        vga_read_clk   : in std_logic;
        
        reset          : in std_logic;   
        oam_we         : in std_logic;
        oam_addr       : in std_logic_vector(5 downto 0);
        oam_din        : in std_logic_vector(31 downto 0);
        
        vram_we_a      : in std_logic;
        vram_addr_a    : in std_logic_vector(10 downto 0); 
        vram_din_a     : in std_logic_vector(7 downto 0);
        
        hud_we_a       : in std_logic;
        hud_addr_a     : in std_logic_vector(8 downto 0);
        hud_din_a      : in std_logic_vector(8 downto 0);
        
        bram_addr_a    : out std_logic_vector(15 downto 0);
        bram_clk_a     : out std_logic;
        bram_en_a      : out std_logic;
        bram_data_a    : in  std_logic_vector(7 downto 0);
        
        bram_addr_b    : out std_logic_vector(15 downto 0);
        bram_clk_b     : out std_logic;
        bram_en_b      : out std_logic;
        bram_data_b    : in  std_logic_vector(7 downto 0);
        
        font_ram_addr  : out std_logic_vector(8 downto 0);
        font_ram_clk   : out std_logic;
        font_ram_en    : out std_logic;
        font_ram_data  : in std_logic_vector(7 downto 0);   
        
        scroll_x       : in std_logic_vector(15 downto 0);
        scroll_y       : in std_logic_vector(15 downto 0);
        
        collision_lo   : out std_logic_vector(31 downto 0);
        collision_hi   : out std_logic_vector(31 downto 0);
        
        VGA_R          : out std_logic_vector(3 downto 0); 
        VGA_G          : out std_logic_vector(3 downto 0); 
        VGA_B          : out std_logic_vector(3 downto 0); 
        VGA_VS         : out std_logic; 
        VGA_HS         : out std_logic 
  );
end sprite_renderer;

architecture Behavioral of sprite_renderer is

    component vga_controller is
      Port (
            pixel_clk  : in std_logic;
            reset      : in std_logic;
            pixel_x    : out std_logic_vector(10 downto 0);
            pixel_y    : out std_logic_vector(10 downto 0);
            video_on   : out std_logic;
            VGA_HS     : out std_logic;
            VGA_VS     : out std_logic;
            line_done  : out std_logic
       );
    end component;

    component ping_pong_line_buffer is
      Port (clk_sprite   : in std_logic;
            clk_vga       : in std_logic;
            
            prod_wr_we      : in std_logic;
            prod_wr_addr : in std_logic_vector(10 downto 0);
            prod_wr_din  : in std_logic_vector(8 downto 0);
            prod_rd_addr : in std_logic_vector(10 downto 0);
            prod_rd_dout : out std_logic_vector(8 downto 0);
            
            cons_addr    : in std_logic_vector(10 downto 0);
            cons_dout    : out std_logic_vector(8 downto 0)
       );
    end component;

    constant MARIO_WIDTH  : integer := 16;
    constant MARIO_HEIGHT : integer := 16;

    signal pixel_x, pixel_y                  : std_logic_vector(10 downto 0);
    signal video_on, hsync, vsync, line_done : std_logic;
    signal pp_color_index_out : std_logic_vector(8 downto 0);

    signal video_on_d1, hsync_d1, vsync_d1 : std_logic := '0';
    signal pp_toggle_read  : std_logic := '0';
    signal pp_toggle_write : std_logic := '1';
    signal frame_start : std_logic;
    signal fs_d1, fs_d2, fs_d3, fs_pulse : std_logic := '0';
    
    type state_t is (
        IDLE,
        CLEAR_BUFFER,
        SCAN_OAM,
        CHECK_SPRITE,
        DRAW_PIPELINE
    );
    
    signal buffer_state : state_t := IDLE;

    signal clear_x    : unsigned(9 downto 0) := (others => '0');
    signal draw_x     : unsigned(9 downto 0) := (others => '0');
    
    signal prod_rd_addr : std_logic_vector(10 downto 0);
    signal prod_rd_dout : std_logic_vector(8 downto 0);
    
    signal prod_wr_we   : std_logic;
    signal prod_wr_addr : std_logic_vector(10 downto 0);
    signal prod_wr_din  : std_logic_vector(8 downto 0);
    signal cons_addr : std_logic_vector(10 downto 0);
    signal pipe_write_x : std_logic_vector(9 downto 0) := (others => '0');

    signal local_next_line : unsigned(10 downto 0) := (others => '0');
    
    type oam_array_t is array (0 to 63) of std_logic_vector(31 downto 0);
    signal OAM : oam_array_t := (others => (others => '0'));

    signal oam_idx      : integer range 0 to 63 := 0;
    signal current_obj  : std_logic_vector(31 downto 0);

    alias obj_en_raw   : std_logic is current_obj(31);
    alias obj_size_raw : std_logic is current_obj(30);
    alias obj_x_raw    : std_logic_vector(9 downto 0) is current_obj(28 downto 19);
    alias obj_y_raw    : std_logic_vector(9 downto 0) is current_obj(18 downto 9);
    alias obj_flip_raw : std_logic is current_obj(8);
    alias obj_id_raw   : std_logic_vector(7 downto 0)  is current_obj(7 downto 0);
    
    signal line_done_d1    : std_logic;
    signal line_done_d2    : std_logic;
    signal line_done_d3    : std_logic;
    signal line_done_pulse : std_logic;
    
    type vram_array_t is array (0 to 2047) of std_logic_vector(7 downto 0);
    signal VRAM : vram_array_t := (others => (others => '0'));
    attribute ram_style : string;
    attribute ram_style of VRAM : signal is "block";
    
    signal vram_addr_c     : std_logic_vector(10 downto 0);
    signal vram_data_out_c : std_logic_vector(7 downto 0);
    
    
    type hud_array_t is array (0 to 511) of std_logic_vector(8 downto 0);
    signal HUD_RAM : hud_array_t := (others => (others => '0'));
    attribute ram_style of HUD_RAM : signal is "block";
    
    signal hud_addr_c     : std_logic_vector(8 downto 0);
    signal hud_data_out_c : std_logic_vector(8 downto 0);
    
    signal font_ram_addr_b     : std_logic_vector(8 downto 0);
    signal font_ram_data_out_b : std_logic_vector(7 downto 0);
    
   --color palette LUT
    type color_ram is array(0 to 255) of std_logic_vector(11 downto 0);
    signal palette : color_ram := (
        0  => x"F0F", -- RGB: 255,   0, 255 (Transparent/Magenta)
        1  => x"59F", -- RGB:  92, 147, 252 (Sky Blue)
        2  => x"C40", -- RGB: 200,  76,  12 (Mario Red)
        3  => x"FBB", -- RGB: 252, 188, 176 (Mario Skin)
        4  => x"000", -- RGB:   0,   0,   0 (Black)
        5  => x"B32", -- RGB: 181,  49,  32 (Brown)
        6  => x"E92", -- RGB: 234, 158,  34 (Yellow)
        7  => x"660", -- RGB: 107, 109,   0 (Shadow/Green)
        others => (others => '0')
    );
    --monitor pipeline 
    signal pipe_x_1, pipe_x_2, pipe_x_3, pipe_x_4 : std_logic_vector(10 downto 0);
    signal pipe_y_1, pipe_y_2                     : std_logic_vector(3 downto 0);
    
    signal video_on_1, hsync_1, vsync_1 : std_logic := '0';
    signal video_on_2, hsync_2, vsync_2 : std_logic := '0';
    signal video_on_3, hsync_3, vsync_3 : std_logic := '0';
    signal video_on_4, hsync_4, vsync_4 : std_logic := '0';
    signal video_on_5, hsync_5, vsync_5 : std_logic := '0';
    signal final_vga_color              : std_logic_vector(11 downto 0);
    signal pipe_bkg_x_1, pipe_bkg_x_2 : std_logic_vector(3 downto 0);
    
    signal virt_x, virt_y : std_logic_vector(10 downto 0);
    signal in_hud_1, in_hud_2, in_hud_3, in_hud_4 : std_logic := '0';
    signal pipe_virt_x_1, pipe_virt_x_2, pipe_virt_x_3, pipe_virt_x_4 : std_logic_vector(2 downto 0);
    signal pipe_virt_y_1, pipe_virt_y_2 : std_logic_vector(2 downto 0);
    
    signal line_toggle    : std_logic := '0';
    
    --colision detection
    signal collision_reg   : std_logic_vector(63 downto 0) := (others => '0');
    signal collision_latch : std_logic_vector(63 downto 0) := (others => '0');
    
begin
    
    frame_start <= '1' when pixel_x = "00000000000" and pixel_y = "00000000000" else '0';
    virt_x <= "0" & pixel_x(10 downto 1);
    virt_y <= "0" & pixel_y(10 downto 1);
    bram_clk_a  <= mem_write_clk;
    bram_en_a   <= '1';
    bram_clk_b  <= vga_read_clk;
    bram_en_b   <= '1';
    font_ram_clk <= vga_read_clk;
    font_ram_en  <= '1';
    
    --collision out 
    collision_lo <= collision_latch(31 downto 0);
    collision_hi <= collision_latch(63 downto 32);
        
    monitor_draw : vga_controller port map(
        pixel_clk  => vga_read_clk,
        reset      => reset,
        pixel_x    => pixel_x,
        pixel_y    => pixel_y,
        video_on   => video_on,
        VGA_HS     => hsync,
        VGA_VS     => vsync,
        line_done  => line_done
    );

    line_buffer : ping_pong_line_buffer port map(
        clk_sprite   => mem_write_clk,
        clk_vga      => vga_read_clk,
        prod_rd_addr => prod_rd_addr,
        prod_rd_dout => prod_rd_dout,
        prod_wr_we   => prod_wr_we,
        prod_wr_addr => prod_wr_addr,
        prod_wr_din  => prod_wr_din,
        cons_addr    => cons_addr,
        cons_dout    => pp_color_index_out
    );
    
    --tilemap id 
    process(mem_write_clk)
    begin
        if rising_edge(mem_write_clk) then
            if vram_we_a = '1' then 
                VRAM(to_integer(unsigned(vram_addr_a))) <= vram_din_a;
            end if;
        end if;
    end process;
    
    process(vga_read_clk)
    begin
        if rising_edge(vga_read_clk) then
            vram_data_out_c <= VRAM(to_integer(unsigned(vram_addr_c)));
        end if;
    end process;
    
    --write to hud ram
    process(mem_write_clk)
    begin
        if rising_edge(mem_write_clk) then
            if hud_we_a = '1' then
                HUD_RAM(to_integer(unsigned(hud_addr_a))) <= hud_din_a;
            end if;
        end if;
    end process;
    
    --read from hud ram
    process(vga_read_clk)
    begin
        if rising_edge(vga_read_clk) then
            hud_data_out_c <= HUD_RAM(to_integer(unsigned(hud_addr_c)));
        end if;
    end process;
    
    --double flop + edge detection
    process(mem_write_clk)
    begin             
        if rising_edge(mem_write_clk) then
            if reset = '1' then 
                line_done_d1    <= '0';      
                line_done_d2    <= '0';
                line_done_d3    <= '0';
                line_done_pulse <= '0';
            else 
                line_done_d1 <= line_done;
                line_done_d2 <= line_done_d1;
                line_done_d3 <= line_done_d2;
                
                if line_done_d3 = '0' and line_done_d2 = '1' then
                    line_done_pulse <= '1';
                else 
                    line_done_pulse <= '0';            
                end if;
                
                fs_d1 <= frame_start;
                fs_d2 <= fs_d1;
                fs_d3 <= fs_d2;
                
                if fs_d3 = '0' and fs_d2 = '1' then
                    fs_pulse <= '1';
                else
                    fs_pulse <= '0';
                end if; 
            end if;
        end if;
    end process;


    --monitor out
    VGA_R  <= final_vga_color(11 downto 8) when video_on_5 = '1' else "0000";
    VGA_G  <= final_vga_color(7 downto 4)  when video_on_5 = '1' else "0000";
    VGA_B  <= final_vga_color(3 downto 0)  when video_on_5 = '1' else "0000";
    VGA_HS <= hsync_5;
    VGA_VS <= vsync_5;

    
    --mem update
    process(mem_write_clk)
    begin
        if rising_edge(mem_write_clk) then
            if oam_we = '1' then
                OAM(to_integer(unsigned(oam_addr))) <= oam_din;
            end if;
        end if;
    end process;
    
    --bkg draw 
   process(vga_read_clk)
        variable world_x : unsigned(10 downto 0);
        variable world_y : unsigned(10 downto 0);
        variable font_bit_idx : integer range 0 to 7;
    begin
        if rising_edge(vga_read_clk) then
            if reset = '1' then
                pp_toggle_read <= '0';
            else
                if line_done = '1' then
                    pp_toggle_read <= not pp_toggle_read;
                end if;
                
                world_x := unsigned(virt_x) + unsigned(scroll_x(10 downto 0));
                world_y := unsigned(virt_y) + unsigned(scroll_y(10 downto 0));
                
                -- stage1
                vram_addr_c  <= std_logic_vector(world_y(8 downto 4)) & std_logic_vector(world_x(9 downto 4));
                hud_addr_c   <= '0' & virt_y(4 downto 3) & virt_x(8 downto 3);
                
                if unsigned(virt_y) < 32 then
                    in_hud_1 <= '1';
                else
                    in_hud_1 <= '0';
                end if;
                
                pipe_x_1      <= virt_x; 
                pipe_y_1      <= std_logic_vector(world_y(3 downto 0)); 
                pipe_bkg_x_1  <= std_logic_vector(world_x(3 downto 0));
                pipe_virt_x_1 <= virt_x(2 downto 0);
                pipe_virt_y_1 <= virt_y(2 downto 0); 
                
                video_on_1  <= video_on; hsync_1 <= hsync; vsync_1 <= vsync;
                
                -- stage2
                pipe_x_2     <= pipe_x_1;
                pipe_y_2     <= pipe_y_1;
                pipe_bkg_x_2 <= pipe_bkg_x_1; 
                pipe_virt_x_2 <= pipe_virt_x_1;
                pipe_virt_y_2 <= pipe_virt_y_1;
                in_hud_2      <= in_hud_1;
                
                video_on_2  <= video_on_1; hsync_2 <= hsync_1; vsync_2 <= vsync_1;
                
                -- stage3
                bram_addr_b   <= vram_data_out_c & pipe_y_2 & pipe_bkg_x_2;
                cons_addr     <= pp_toggle_read & pipe_x_2(9 downto 0);
                font_ram_addr <= hud_data_out_c(5 downto 0) & pipe_virt_y_2;
                
                pipe_x_3    <= pipe_x_2;
                pipe_virt_x_3 <= pipe_virt_x_2;
                in_hud_3      <= in_hud_2;
                
                video_on_3  <= video_on_2; hsync_3 <= hsync_2; vsync_3 <= vsync_2;
                
                -- stage4
                pipe_x_4    <= pipe_x_3;
                pipe_virt_x_4 <= pipe_virt_x_3;
                in_hud_4      <= in_hud_3;
                
                video_on_4  <= video_on_3; hsync_4 <= hsync_3; vsync_4 <= vsync_3;
                
                -- stage5
                font_bit_idx := 7 - to_integer(unsigned(pipe_virt_x_4));
                
                if in_hud_4 = '1' and font_ram_data(font_bit_idx) = '1' then
                    final_vga_color <= x"FFF"; 
                    
                elsif pp_color_index_out(7 downto 0) /= x"00" then
                    final_vga_color <= palette(to_integer(unsigned(pp_color_index_out(7 downto 0))));
                    
                else
                    final_vga_color <= palette(to_integer(unsigned(bram_data_b)));   
                end if;
                
                video_on_5 <= video_on_4; hsync_5 <= hsync_4; vsync_5 <= vsync_4;                
                
            end if;
        end if;
    end process;
    
    -- fsm for line assembly
    process(mem_write_clk)
        variable offset_y : unsigned(10 downto 0) := (others => '0');
    begin
        if rising_edge(mem_write_clk) then
            if reset = '1' then
                buffer_state      <= IDLE;
                prod_wr_we        <= '0';
                pp_toggle_write   <= '1';
                local_next_line   <= (others => '0');        
                collision_reg     <= (others => '0'); 
                collision_latch   <= (others => '0'); 
            else
                if fs_pulse = '1' then
                    local_next_line <= (others => '0');
                    line_toggle     <= '0';
                    collision_latch <= collision_reg;
                    collision_reg   <= (others => '0');
                end if;
                
                case buffer_state is
                    when IDLE =>
                        prod_wr_we <= '0';
                        if line_done_pulse = '1' then
                            line_toggle <= not line_toggle;
                            if line_toggle = '1' then 
                                if local_next_line = 262 then
                                    local_next_line <= (others => '0');
                                else
                                    local_next_line <= local_next_line + 1;
                                end if;
                            end if;
                            
                            oam_idx         <= 0;
                            clear_x         <= (others => '0');
                            pp_toggle_write <= not pp_toggle_write;
                            buffer_state    <= CLEAR_BUFFER;
                        end if;
                        
                    when CLEAR_BUFFER =>
                        prod_wr_we   <= '1';
                        prod_wr_addr <= pp_toggle_write & std_logic_vector(clear_x);
                        prod_wr_din  <= (others => '0');                  
                        
                        if clear_x = 319 then
                            buffer_state <= SCAN_OAM;
                        else
                            clear_x <= clear_x + 1;
                        end if;

                    when SCAN_OAM => 
                        prod_wr_we      <= '0';
                        current_obj  <= OAM(oam_idx);
                        buffer_state <= CHECK_SPRITE;           
                                                                       
                    when CHECK_SPRITE =>
                        prod_wr_we <= '0';
                        offset_y := local_next_line - unsigned(obj_y_raw);
                        
                        if obj_en_raw = '1' and offset_y < 16 then
                            draw_x <= (others => '0');
                            buffer_state <= DRAW_PIPELINE;
                        else
                            if oam_idx = 63 then
                                buffer_state <= IDLE;
                            else
                                oam_idx <= oam_idx + 1;
                                buffer_state <= SCAN_OAM; 
                            end if;                                                
                        end if;
                        
                     when DRAW_PIPELINE =>
                     --draw
                        if draw_x >= 2 and draw_x <= 17 then
                            if bram_data_a /= x"00" and (unsigned(obj_x_raw) + (draw_x - 2)) < 320 then
                                prod_wr_addr <= pp_toggle_write & std_logic_vector(resize(unsigned(obj_x_raw) + (draw_x - 2), 10));         
                                
                                if oam_idx = 0 then 
                                    prod_wr_we <= '1';
                                    prod_wr_din <= '1' & bram_data_a(7 downto 0); 
                                else
                                    if prod_rd_dout(8) = '1' then
                                        prod_wr_we <= '0'; 
                                        collision_reg(oam_idx) <= '1';
                                    else
                                        prod_wr_we <= '1';
                                        prod_wr_din <= '0' & bram_data_a(7 downto 0);
                                    end if;
                                end if;
                            else
                                prod_wr_we <= '0';
                            end if;
                        else
                            prod_wr_we <= '0';
                        end if;
                     
                     --request
                        if draw_x < 16 then
                            if obj_flip_raw = '1' then
                               bram_addr_a <= obj_id_raw & std_logic_vector(offset_y(3 downto 0)) & std_logic_vector(to_unsigned(15, 4) - draw_x(3 downto 0));
                            else
                                bram_addr_a <= obj_id_raw & std_logic_vector(offset_y(3 downto 0)) & std_logic_vector(draw_x(3 downto 0));
                            end if;
                            
                            prod_rd_addr <= pp_toggle_write & std_logic_vector(resize(unsigned(obj_x_raw) + draw_x, 10));         
                        end if;
                        
                     --exit
                        if draw_x = 17 then
                            if oam_idx = 63 then
                                buffer_state <= IDLE;
                            else 
                                oam_idx <= oam_idx + 1;
                                buffer_state <= SCAN_OAM;
                            end if; 
                        else
                            draw_x <= draw_x + 1;
                        end if;
                end case;
            end if;
        end if;
    end process;

    
    
end Behavioral;