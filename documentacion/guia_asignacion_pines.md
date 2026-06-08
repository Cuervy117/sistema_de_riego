# Guía de Asignación de Pines en RZ-EasyFPGA A2.2 (Cyclone IV)

Esta guía explica cómo mapear los puertos de entrada/salida de nuestro sistema de riego y ventilación (`sistema_riego_top`) en la tarjeta de desarrollo **RZ-EasyFPGA A2.2** (chip Altera/Intel **Cyclone IV EP4CE6E22C8N**).

---

## 1. Conexiones Físicas de la Tarjeta

La tarjeta RZ-EasyFPGA A2.2 cuenta con periféricos integrados (LEDs, botones de usuario, reloj) y puertos de expansión (headers GPIO) para conectar módulos externos como el ADC MCP3008, el servomotor y el relé de la bomba.

### A. Periféricos Integrados (On-board)

Los periféricos onboard en esta tarjeta utilizan lógica **Active-Low** (se activan enviando un `'0'` lógico y se apagan con un `'1'`). Dado que nuestro diseño espera salidas Active-High para LEDs/Bomba y entradas Active-Low para el Reset, las conexiones se mapean de la siguiente manera:

| Puerto del Diseño (`sistema_riego_top`) | Periférico Físico en Placa | Pin Físico (FPGA) | Notas / Comportamiento |
| :--- | :--- | :--- | :--- |
| `clk` | Oscilador de 50 MHz | **PIN_23** | Reloj del sistema. |
| `reset_n` | Botón `KEY[0]` (S1) | **PIN_88** | Entrada síncrona. Presionado es `'0'` (Reset). |
| `sw_bomba_n` | Botón `KEY[1]` (S2) | **PIN_89** | Interruptor manual bomba. Presionado es `'0'` (ON). |
| `led_state[0]` | `LEDG[0]` (LED D1) | **PIN_87** | Bit 0 del estado (Verde). Se ilumina en `'0'`. |
| `led_state[1]` | `LEDG[1]` (LED D2) | **PIN_86** | Bit 1 del estado (Verde). Se ilumina en `'0'`. |
| `led_state[2]` | `LEDG[2]` (LED D3) | **PIN_85** | Bit 2 del estado (Verde). Se ilumina en `'0'`. |
| `led_bomba` | `LEDG[3]` (LED D4) | **PIN_84** | Indica bomba encendida (Verde). Se ilumina en `'0'`. |

> [!NOTE]
> Como los LEDs en la placa física son Active-Low (se encienden en `'0'`), si deseas que se iluminen correctamente con la lógica positiva del diseño, puedes invertir la asignación física en el archivo top-level (ej. `led_state_fisico <= not led_state;`) o simplemente recordar que un LED apagado en la placa física representa un `'1'` lógico en el simulador.

### B. Módulos Externos (Headers de Expansión GPIO)

Para el ADC MCP3008, el Servomotor y el control de la Bomba, debemos utilizar pines libres en los headers de expansión de la tarjeta. Se recomiendan pines que no estén pre-conectados a memorias críticas como la SDRAM para evitar conflictos:

| Puerto del Diseño (`sistema_riego_top`) | Dispositivo Externo | Pin Físico Sugerido | Ubicación en Header |
| :--- | :--- | :--- | :--- |
| **`adc_sclk`** | MCP3008 CLK (Pin 13) | **PIN_112** | Header de Expansión |
| **`adc_cs_n`** | MCP3008 CS/SHDN (Pin 10)| **PIN_113** | Header de Expansión |
| **`adc_mosi`** | MCP3008 DIN (Pin 11) | **PIN_114** | Header de Expansión |
| **`adc_miso`** | MCP3008 DOUT (Pin 12)| **PIN_115** | Header de Expansión |
| **`bomba`** | Relé / MOSFET (Control) | **PIN_119** | Header de Expansión |
| **`servo_pwm`** | Servomotor SG90 (Señal) | **PIN_120** | Header de Expansión |
| **`led_uv_warning`**| LED de Alarma (Rojo) | **PIN_110** | *Opcional:* Conectado al **Buzzer** integrado para generar alerta sonora, o a un pin del header. |

---

## 2. Configuración en Quartus Prime

Tienes dos métodos para aplicar estas restricciones en tu proyecto de Quartus.

### Método 1: Escribir directamente en el archivo `.qsf` (Recomendado)

Abre el archivo de configuración de Quartus de tu proyecto (con extensión `.qsf`) y agrega las siguientes líneas al final del archivo:

```tcl
# ==============================================================================
# Restricciones de Pines - Proyecto Riego (RZ-EasyFPGA A2.2)
# ==============================================================================

# Configuración del Reloj, Reset y Control Manual
set_location_assignment PIN_23 -to clk
set_location_assignment PIN_88 -to reset_n
set_location_assignment PIN_89 -to sw_bomba_n

# Interfaz SPI del ADC MCP3008
set_location_assignment PIN_112 -to adc_sclk
set_location_assignment PIN_113 -to adc_cs_n
set_location_assignment PIN_114 -to adc_mosi
set_location_assignment PIN_115 -to adc_miso

# Actuadores
set_location_assignment PIN_119 -to bomba
set_location_assignment PIN_120 -to servo_pwm

# Diagnóstico visual y alarmas
set_location_assignment PIN_87 -to led_state[0]
set_location_assignment PIN_86 -to led_state[1]
set_location_assignment PIN_85 -to led_state[2]
set_location_assignment PIN_84 -to led_bomba
set_location_assignment PIN_110 -to led_uv_warning
```

### Método 2: Uso del Pin Planner (Visual)

1. Abre tu proyecto en **Quartus Prime**.
2. Compila el diseño una vez (dale doble clic a *Analysis & Synthesis*) para que Quartus reconozca los nombres de tus puertos.
3. Ve al menú superior y haz clic en **Assignments > Pin Planner**.
4. En la parte inferior, verás la lista de puertos del diseño. En la columna **Location**, escribe el número de pin correspondiente (ej. escribe `PIN_23` en la fila de `clk`).
5. En la columna **I/O Standard**, asegúrate de que todos los pines estén configurados como **3.3-V LVTTL** (estándar eléctrico de esta placa).
6. Cierra el Pin Planner (se guarda automáticamente) y vuelve a compilar completamente.

---

## 3. Resolviendo Conflictos Comunes en Cyclone IV

Al compilar para el chip `EP4CE6E22C8`, Quartus podría arrojar advertencias o errores sobre pines de doble propósito. Sigue estos pasos para solucionarlo:

### Deshabilitar pin `nCEO` como control
El pin 101 se comparte con el protocolo VGA y de configuración. Si lo usas y compilas, Quartus te dará error.
1. En Quartus, haz clic derecho sobre el dispositivo en el panel de jerarquía y selecciona **Device**.
2. Haz clic en **Device and Pin Options...**
3. Ve a la categoría **Dual-Purpose Pins**.
4. Busca el pin **nCEO** y cambia su valor de *"Use as programming pin"* a **"Use as regular I/O"**.
5. Presiona OK.

### Configurar los pines no usados como Triestado
Para proteger la FPGA de cortocircuitos accidentales en los pines que no estás conectando:
1. En la misma ventana de **Device and Pin Options...**, ve a la categoría **Unused Pins**.
2. Cambia el valor a **"As input tri-stated"** (como entradas en alta impedancia).
3. Presiona OK y vuelve a compilar.
