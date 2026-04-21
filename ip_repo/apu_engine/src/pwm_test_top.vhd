library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity apu_engine is
    Port ( 
        clk100Mhz        : in std_logic;
        reset_n          : in std_logic;
        
        s_axis_apu_ready : out std_logic;
        s_axis_apu_valid : in std_logic;
        s_axis_apu_data  : in std_logic_vector(31 downto 0); 
        
        AUD_PWM      : out std_logic;
        AUD_SD       : out std_logic
    );
end apu_engine;

architecture Behavioral of apu_engine is

    signal sample_timer : integer range 0 to 4535 := 0;
    signal byte_index   : integer range 0 to 3 := 0; 
    
    signal pwm_cnt      : unsigned(7 downto 0) := (others => '0');
    signal audio_sample : unsigned(7 downto 0) := (others => '0');
    
    signal current_word : std_logic_vector(31 downto 0) := (others => '0');
    signal ready_reg    : std_logic := '1';
    signal has_data     : std_logic := '0';
    
begin

    AUD_SD <= '1'; 
    
    process(clk100Mhz)
    begin
        if rising_edge(clk100Mhz) then
            if reset_n = '0' then 
                pwm_cnt        <= (others => '0');
                sample_timer   <= 0;
                byte_index     <= 0;
                audio_sample   <= (others => '0');
                AUD_PWM        <= '0';
                current_word   <= (others => '0');
                ready_reg      <= '1';
                has_data       <= '0';
                audio_sample   <= x"80";
            else
                
               
                if ready_reg = '1' and s_axis_apu_valid = '1' then
                    current_word <= s_axis_apu_data;
                    ready_reg    <= '0';
                    has_data     <= '1';
                end if;
                
                if sample_timer = 4535 then 
                    sample_timer <= 0;
                    
                    if has_data = '1' then
                        case byte_index is
                            when 0 => audio_sample <= unsigned(current_word(7 downto 0));
                            when 1 => audio_sample <= unsigned(current_word(15 downto 8));
                            when 2 => audio_sample <= unsigned(current_word(23 downto 16));
                            when 3 => audio_sample <= unsigned(current_word(31 downto 24));
                        end case;
                        
                        if byte_index = 3 then
                            byte_index <= 0;
                            ready_reg  <= '1';
                            has_data   <= '0'; 
                        else
                            byte_index <= byte_index + 1;
                        end if;
                    else
                        audio_sample <= x"80";
                    end if;
                    
                else
                    sample_timer <= sample_timer + 1;
                end if;

                pwm_cnt <= pwm_cnt + 1;
                if pwm_cnt < audio_sample then
                    AUD_PWM <= '1';
                else
                    AUD_PWM <= '0';
                end if;

            end if;
        end if;
    end process;
    
    s_axis_apu_ready <= ready_reg;

end Behavioral;