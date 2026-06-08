library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sistema_riego_top is
    generic (
        CLK_FREQ          : integer := 50000000; -- 50 MHz Clock
        CLK_DIVIDER       : integer := 50;       -- Divisor para reloj SPI (50 MHz / 50 = 1 MHz SPI)
        ADC_SAMPLE_PERIOD : integer := 500000;   -- Muestreo cada 10ms
        
        -- Thresholds
        TH_HUM_DRY        : integer := 700;
        TH_HUM_WET        : integer := 400;

        TH_TEMP_HOT       : integer := 250;
        TH_TEMP_COOL      : integer := 200;
        
        TH_UV_HIGH        : integer := 600;
        TH_UV_NORMAL      : integer := 450;
        
        -- Timeouts
        TIMEOUT_RIEGO_S   : integer := 10;
        COOLDOWN_DURATION : integer := 5
    );
    port (
        clk             : in  std_logic;
        reset_n         : in  std_logic; -- Active-low async reset from push-button (KEY[0])
        sw_bomba_n      : in  std_logic; -- Active-low manual override for water pump (KEY[1])
        
        -- MCP3008 SPI Interface
        adc_sclk        : out std_logic;
        adc_cs_n        : out std_logic;
        adc_mosi        : out std_logic;
        adc_miso        : in  std_logic;
        
        -- Actuators
        bomba           : out std_logic;
        servo_pwm       : out std_logic;
        
        -- Visual Status (LEDs / Debug)
        led_state       : out std_logic_vector(2 downto 0);
        led_bomba       : out std_logic;
        led_uv_warning  : out std_logic
    );
end entity sistema_riego_top;

architecture structural of sistema_riego_top is
    -- Reset synchronizer signals
    signal rst_sync_reg1 : std_logic := '1';
    signal rst_sync_reg2 : std_logic := '1';
    signal rst           : std_logic; -- Internal active-high synchronized reset
    
    -- SPI internal signals
    signal spi_start   : std_logic;
    signal spi_tx_data : std_logic_vector(23 downto 0);
    signal spi_rx_data : std_logic_vector(23 downto 0);
    signal spi_busy    : std_logic;
    signal spi_done    : std_logic;
    
    -- Sensor values
    signal hum_val     : std_logic_vector(9 downto 0);
    signal temp_val    : std_logic_vector(9 downto 0);
    signal uv_val      : std_logic_vector(9 downto 0);
    signal adc_valid   : std_logic;
    
    -- Comparator alarms
    signal hum_baja    : std_logic;
    signal temp_alta   : std_logic;
    signal uv_extrema  : std_logic;
    
    -- FSM controls
    signal bomba_on    : std_logic;
    signal gate_open   : std_logic;
    signal fsm_state   : std_logic_vector(2 downto 0);

begin
    -- 2-FF Reset Synchronizer (Active-low async to Active-high sync)
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            rst_sync_reg1 <= '1';
            rst_sync_reg2 <= '1';
        elsif rising_edge(clk) then
            rst_sync_reg1 <= '0';
            rst_sync_reg2 <= rst_sync_reg1;
        end if;
    end process;
    
    rst <= rst_sync_reg2;
    
    -- Visual Outputs Mapping (Inverted for physical Active-Low LEDs)
    led_bomba      <= not (bomba_on or (not sw_bomba_n));
    led_uv_warning <= not uv_extrema;
    led_state      <= not fsm_state;
    bomba          <= bomba_on or (not sw_bomba_n); -- Actuator is active-high, active if FSM or button pressed

    u_spi_master : entity work.spi_master
        generic map (
            CLK_DIVIDER => CLK_DIVIDER
        )
        port map (
            clk      => clk,
            rst      => rst,
            start    => spi_start,
            tx_data  => spi_tx_data,
            rx_data  => spi_rx_data,
            busy     => spi_busy,
            done     => spi_done,
            sclk     => adc_sclk,
            cs_n     => adc_cs_n,
            mosi     => adc_mosi,
            miso     => adc_miso
        );

    -- Instantiate ADC Controller
    u_adc_controller : entity work.adc_controller
        generic map (
            SAMPLE_PERIOD => ADC_SAMPLE_PERIOD
        )
        port map (
            clk         => clk,
            rst         => rst,
            spi_start   => spi_start,
            spi_tx_data => spi_tx_data,
            spi_rx_data => spi_rx_data,
            spi_busy    => spi_busy,
            spi_done    => spi_done,
            humedad_val => hum_val,
            temp_val    => temp_val,
            uv_val      => uv_val,
            data_ready  => adc_valid
        );

    -- Instantiate Threshold Comparator
    u_threshold_comparator : entity work.threshold_comparator
        generic map (
            TH_HUM_DRY   => TH_HUM_DRY,
            TH_HUM_WET   => TH_HUM_WET,
            TH_TEMP_HOT  => TH_TEMP_HOT,
            TH_TEMP_COOL => TH_TEMP_COOL,
            TH_UV_HIGH   => TH_UV_HIGH,
            TH_UV_NORMAL => TH_UV_NORMAL
        )
        port map (
            clk          => clk,
            rst          => rst,
            humedad_val  => hum_val,
            temp_val     => temp_val,
            uv_val       => uv_val,
            data_valid   => adc_valid,
            humedad_baja => hum_baja,
            temp_alta    => temp_alta,
            uv_extrema   => uv_extrema
        );

    -- Instantiate PWM Controller
    u_pwm_controller : entity work.pwm_controller
        generic map (
            CLK_FREQ      => CLK_FREQ,
            PWM_FREQ      => 50,
            PULSE_MIN_US  => 1000,
            PULSE_MAX_US  => 2000,
            PULSE_STOP_US => 1500
        )
        port map (
            clk       => clk,
            rst       => rst,
            gate_open => gate_open,
            pwm_out   => servo_pwm
        );

    -- Instantiate FSM Central
    u_fsm_central : entity work.fsm_central
        generic map (
            CLK_FREQ          => CLK_FREQ,
            TIMEOUT_RIEGO_S   => TIMEOUT_RIEGO_S,
            COOLDOWN_DURATION => COOLDOWN_DURATION
        )
        port map (
            clk          => clk,
            rst          => rst,
            humedad_baja => hum_baja,
            temp_alta    => temp_alta,
            uv_extrema   => uv_extrema,
            bomba_on     => bomba_on,
            gate_open    => gate_open,
            state_debug  => fsm_state
        );

end architecture structural;
