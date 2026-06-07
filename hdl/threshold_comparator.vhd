library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity threshold_comparator is
    generic (
        -- Soil Moisture thresholds (high ADC value = dry, low ADC value = wet)
        TH_HUM_DRY  : integer := 700; -- Trigger watering when above this
        TH_HUM_WET  : integer := 400; -- Stop watering when below this
        
        -- Temperature thresholds (high ADC value = hot, low ADC value = cool)
        TH_TEMP_HOT  : integer := 250; -- Trigger fan/ventilation when above this (~30°C for TEMP235)
        TH_TEMP_COOL : integer := 200; -- Stop ventilation when below this (~24°C for TEMP235)
        
        -- UV Radiation thresholds (high ADC value = intense sunlight)
        TH_UV_HIGH   : integer := 600; -- Trigger UV-High warning when above this
        TH_UV_NORMAL : integer := 450  -- Clear UV-High warning when below this
    );
    port (
        clk          : in  std_logic;
        rst          : in  std_logic;
        
        -- Raw ADC values
        humedad_val  : in  std_logic_vector(9 downto 0);
        temp_val     : in  std_logic_vector(9 downto 0);
        uv_val       : in  std_logic_vector(9 downto 0);
        data_valid   : in  std_logic; -- Strobe indicating new ADC data
        
        -- Alarm/Status outputs
        humedad_baja : out std_logic; -- '1' means dry (needs watering)
        temp_alta    : out std_logic; -- '1' means hot (needs cooling)
        uv_extrema   : out std_logic  -- '1' means high UV (block watering)
    );
end entity threshold_comparator;

architecture rtl of threshold_comparator is
    signal hum_baja_i : std_logic := '0';
    signal temp_alta_i : std_logic := '0';
    signal uv_extrema_i : std_logic := '0';
begin
    -- Assign outputs
    humedad_baja <= hum_baja_i;
    temp_alta    <= temp_alta_i;
    uv_extrema   <= uv_extrema_i;

    -- Soil Moisture Hysteresis
    process(clk, rst)
    begin
        if rst = '1' then
            hum_baja_i <= '0';
        elsif rising_edge(clk) then
            if data_valid = '1' then
                if unsigned(humedad_val) > TH_HUM_DRY then
                    hum_baja_i <= '1'; -- Soil is too dry, trigger watering request
                elsif unsigned(humedad_val) < TH_HUM_WET then
                    hum_baja_i <= '0'; -- Soil is wet enough, clear request
                end if;
            end if;
        end if;
    end process;

    -- Temperature Hysteresis
    process(clk, rst)
    begin
        if rst = '1' then
            temp_alta_i <= '0';
        elsif rising_edge(clk) then
            if data_valid = '1' then
                if unsigned(temp_val) > TH_TEMP_HOT then
                    temp_alta_i <= '1'; -- Too hot, trigger ventilation request
                elsif unsigned(temp_val) < TH_TEMP_COOL then
                    temp_alta_i <= '0'; -- Cooled down, clear request
                end if;
            end if;
        end if;
    end process;

    -- UV Hysteresis
    process(clk, rst)
    begin
        if rst = '1' then
            uv_extrema_i <= '0';
        elsif rising_edge(clk) then
            if data_valid = '1' then
                if unsigned(uv_val) > TH_UV_HIGH then
                    uv_extrema_i <= '1'; -- Intense UV detected, block watering
                elsif unsigned(uv_val) < TH_UV_NORMAL then
                    uv_extrema_i <= '0'; -- Safe UV levels, clear block
                end if;
            end if;
        end if;
    end process;

end architecture rtl;
