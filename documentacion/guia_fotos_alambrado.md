# Guía de Registro Fotográfico e Instrumentación
**Proyecto:** Sistema de Riego Automático en FPGA  
**Responsable de Capturas:** Compañero de Brigada  
**Integrante del Proyecto:** Díaz Antúnez David  

Esta guía contiene la lista detallada de fotografías, diagramas e instrumentación necesarios para completar el reporte final en LaTeX. Sigue estas especificaciones para asegurar que las imágenes tengan la calidad técnica adecuada.

---

## 1. Archivos Requeridos y Nombres de Destino
Para que el documento LaTeX compile automáticamente con las imágenes correctas, guarda las fotos en el directorio correspondiente con los nombres y formatos exactos indicados a continuación.

### A. Fotografías del Circuito Físico (Guardar en `documentacion/imagenes/`)
| Nombre de Archivo | Descripción de la Toma | Elementos Clave a Mostrar |
| :--- | :--- | :--- |
| `foto_alambrado_general.png` | **Vista General del Sistema** | Toma panorámica (ángulo de 45°) donde se aprecie la tarjeta FPGA (DE1-SoC), la protoboard de sensores, la bomba sumergible, el servomotor de compuerta y las fuentes de alimentación. |
| `foto_etapa_potencia.png` | **Etapa de Aislamiento y Potencia** | Acercamiento (Macro) enfocado en los optoacopladores (PC817), el relevador/MOSFET de potencia y las conexiones del motor de la bomba sumergible. Debe verse claramente la separación física de tierras. |
| `foto_sensor_adc.png` | **Conexiones del ADC y Sensores** | Acercamiento a la protoboard donde está el circuito integrado **MCP3008**, mostrando las conexiones analógicas de los sensores (Humedad, Temperatura y UV) y las líneas digitales SPI que van a la FPGA. |

### B. Capturas de Instrumentación (Guardar en `documentacion/imagenes/`)
| Nombre de Archivo | Tipo de Captura | Configuración de Instrumento |
| :--- | :--- | :--- |
| `medicion_osciloscopio_pwm.png` | **Señal PWM del Servo** | Captura de pantalla del osciloscopio conectando la sonda al pin GPIO del PWM. Debe mostrar una frecuencia de **50 Hz** (período de 20 ms) y dos estados de ancho de pulso: **1.0 ms** (cerrado) y **2.0 ms** (abierto). |
| `medicion_analizador_logico_spi.png`| **Tramas del Bus SPI** | Captura del analizador lógico digital. Debe mostrar los canales de reloj *SCLK* (a 1 MHz), selección de chip *CS_n* (activa en bajo), *MOSI* (comando de canal) y *MISO* (lectura de 10 bits retornada por el ADC). |

### C. Capturas de Simulación (Guardar en `documentacion/figures/`)
| Nombre de Archivo | Descripción |
| :--- | :--- |
| `captura_simulacion_riego.png` | Captura de GTKWave mostrando la transición de `ST_MONITOR` a `ST_RIEGO` al activarse `humedad_baja = '1'`, y el bloqueo cuando `uv_extrema = '1'`. |
| `captura_simulacion_ventilacion.png`| Captura de GTKWave mostrando el tren de pulsos del PWM incrementándose progresivamente (barrido de ciclo de trabajo) en `ST_VENTILACION`. |
| `captura_simulacion_timeout.png` | Captura de GTKWave del apagado de seguridad de la bomba tras superar el límite de tiempo de riego de 10 segundos. |

---

## 2. Recomendaciones de Calidad y Encuadre

1. **Iluminación:** Evita las sombras duras de la protoboard usando una linterna de celular o lámpara de escritorio. La luz blanca difusa es ideal.
2. **Enfoque y Estabilidad:** Utiliza un tripié o apoya el celular para evitar fotos movidas o borrosas. El texto impreso sobre los chips (como el MCP3008) debe ser legible.
3. **Rotulado de Cables:** Procura que los cables de conexión (Jumpers) estén lo más peinados y ordenados posible para facilitar la comprensión de las conexiones SPI y de potencia en el reporte.
4. **Formato:** Sube las imágenes preferentemente en formato **PNG** sin transparencia. Si tomas las fotos en JPG, conviértelas a PNG o renómbralas acorde a la tabla anterior (LaTeX procesa mejor PNG y PDF para imágenes de alta definición).
