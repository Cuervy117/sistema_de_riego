library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adc_controller is
    generic (
        SAMPLE_PERIOD : integer := 500000 -- 500,000 clock cycles @ 50MHz = 10 ms between cycles
    );
    port (
        clk         : in  std_logic;
        rst         : in  std_logic;
        
        -- Connections to spi_master
        spi_start   : out std_logic;
        spi_tx_data : out std_logic_vector(23 downto 0);
        spi_rx_data : in  std_logic_vector(23 downto 0);
        spi_busy    : in  std_logic;
        spi_done    : in  std_logic;
        
        -- Demultiplexed Sensor Values
        humedad_val : out std_logic_vector(9 downto 0);
        temp_val    : out std_logic_vector(9 downto 0);
        uv_val      : out std_logic_vector(9 downto 0);
        data_ready  : out std_logic
    );
end entity adc_controller;

architecture rtl of adc_controller is
    type state_type is (ST_WAIT_TIMER, ST_START_CH0, ST_WAIT_CH0, ST_START_CH1, ST_WAIT_CH1, ST_START_CH2, ST_WAIT_CH2, ST_CYCLE_DONE);
    signal state : state_type := ST_WAIT_TIMER;
    
    signal timer_cnt : integer range 0 to SAMPLE_PERIOD := 0;
    
    signal hum_reg   : std_logic_vector(9 downto 0) := (others => '0');
    signal temp_reg  : std_logic_vector(9 downto 0) := (others => '0');
    signal uv_reg    : std_logic_vector(9 downto 0) := (others => '0');
    
begin
    -- Assign outputs
    humedad_val <= hum_reg;
    temp_val    <= temp_reg;
    uv_val      <= uv_reg;

    process(clk, rst)
    begin
        if rst = '1' then
            state       <= ST_WAIT_TIMER;
            timer_cnt   <= 0;
            hum_reg     <= (others => '0');
            temp_reg    <= (others => '0');
            uv_reg      <= (others => '0');
            spi_start   <= '0';
            spi_tx_data <= (others => '0');
            data_ready  <= '0';
        elsif rising_edge(clk) then
            spi_start  <= '0';
            data_ready <= '0';
            
            case state is
                when ST_WAIT_TIMER =>
                    if timer_cnt = SAMPLE_PERIOD - 1 then
                        timer_cnt <= 0;
                        state     <= ST_START_CH0;
                    else
                        timer_cnt <= timer_cnt + 1;
                    end if;
                    
                -- Channel 0: Humedad
                when ST_START_CH0 =>
                    if spi_busy = '0' then
                        -- Start bit '1' in Byte 1
                        -- Config: SGL/DIFF='1', D2='0', D1='0', D0='0' (CH0) in Byte 2, followed by 4 dummy bits (1000_0000 = 0x80)
                        spi_tx_data <= x"01" & x"80" & x"00";
                        spi_start   <= '1';
                        state       <= ST_WAIT_CH0;
                    end if;
                    
                when ST_WAIT_CH0 =>
                    if spi_done = '1' then
                        -- Extract 10 bits from rx_data (bits 10 to 1)
                        hum_reg <= spi_rx_data(10 downto 1);
                        state   <= ST_START_CH1;
                    end if;
                    
                -- Channel 1: Temperatura
                when ST_START_CH1 =>
                    if spi_busy = '0' then
                        -- Config: SGL/DIFF='1', D2='0', D1='0', D0='1' (CH1) in Byte 2, followed by 4 dummy bits (1001_0000 = 0x90)
                        spi_tx_data <= x"01" & x"90" & x"00";
                        spi_start   <= '1';
                        state       <= ST_WAIT_CH1;
                    end if;
                    
                when ST_WAIT_CH1 =>
                    if spi_done = '1' then
                        temp_reg <= spi_rx_data(10 downto 1);
                        state    <= ST_START_CH2;
                    end if;
                    
                -- Channel 2: UV
                when ST_START_CH2 =>
                    if spi_busy = '0' then
                        -- Config: SGL/DIFF='1', D2='0', D1='1', D0='0' (CH2) in Byte 2, followed by 4 dummy bits (1010_0000 = 0xA0)
                        spi_tx_data <= x"01" & x"a0" & x"00";
                        spi_start   <= '1';
                        state       <= ST_WAIT_CH2;
                    end if;
                    
                when ST_WAIT_CH2 =>
                    if spi_done = '1' then
                        uv_reg <= spi_rx_data(10 downto 1);
                        state  <= ST_CYCLE_DONE;
                    end if;
                    
                when ST_CYCLE_DONE =>
                    report "ADC readings - Hum: " & integer'image(to_integer(unsigned(hum_reg))) &
                           ", Temp: " & integer'image(to_integer(unsigned(temp_reg))) &
                           ", UV: " & integer'image(to_integer(unsigned(uv_reg)))
                           severity note;
                    data_ready <= '1'; -- Signal FSM and system that new data is available
                    state      <= ST_WAIT_TIMER;
                    
                when others =>
                    state <= ST_WAIT_TIMER;
            end case;
        end if;
    end process;
end architecture rtl;
