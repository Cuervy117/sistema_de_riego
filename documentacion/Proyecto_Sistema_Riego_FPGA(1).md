# Especificación de Proyecto: Sistema de Riego Automático en FPGA

Este documento recopila la propuesta de diseño, el análisis técnico, la arquitectura de hardware y las mejores prácticas para la implementación de un **Sistema de Riego Automático** utilizando lógica digital pura (FSM) sobre una FPGA **Intel/Altera Cyclone V**.

---

## 1. Descripción del Proyecto

El objetivo es diseñar e implementar un sistema de control embebido en hardware para la automatización del riego y aclimatación de un cultivo menor. El sistema procesa variables ambientales en tiempo real y activa de forma concurrente diversos actuadores mecánicos e hidráulicos.

### Componentes del Sistema

| Tipo | Componente | Función Principal |
| :--- | :--- | :--- |
| **Entrada (Sensores)** | Sensor de Humedad de Suelo | Mide el estrés hídrico del sustrato. |
| | Sensor de Temperatura Ambiental | Monitorea el estrés térmico del entorno. |
| | Sensor de Radiación UV | Evalúa la intensidad solar para optimizar las horas de riego. |
| **Control** | FPGA Cyclone V | Procesamiento en paralelo mediante módulos RTL y una FSM central. |
| **Salida (Actuadores)**| Electroválvula | Controla el flujo principal de entrada de agua. |
| | Bomba Sumergible | Presuriza el sistema de riego local. |
| | Servomotor / Ventilador | Regula el flujo de aire o apertura de compuertas térmicas. |

---

## 2. Análisis Crítico y Desafíos de Hardware

Al migrar un sistema tradicionalmente basado en microcontroladores (como Arduino o ESP32) a un entorno VLSI/FPGA, se deben resolver varios desafíos de acoplamiento físico y electrónico:

### A. Naturaleza de las Señales de Entrada (Analógico vs. Digital)
La Cyclone V es un dispositivo estrictamente digital. Sensores analógicos comunes (que varían su voltaje de 0 a 3.3V/5V) **no pueden conectarse directamente a los pines GPIO**.
* **Solución:** Utilizar sensores con interfaz digital nativa (I2C, SPI o protocolos de 1 hilo como el DHT11/DHT22) o integrar un circuito integrado **ADC (Convertidor Analógico-Digital)** externo (como el chip ADC de la placa DE1-SoC) para digitalizar las lecturas antes de enviarlas a la lógica de control.

### B. Aislamiento y Etapa de Potencia
Los pines GPIO de la FPGA operan a niveles lógicos de **3.3V** y toleran corrientes del orden de los **miliamperios (mA)**. Los actuadores (bomba, electroválvula) operan a voltajes mayores (5V, 12V o 24V) y corrientes elevadas.
* **Solución Obligatoria:** Diseñar o acoplar una etapa de potencia aislada mediante **optoacopladores y relés** o **transistores MOSFET de potencia** para evitar el retorno de corrientes parásitas o picos inductivos que destruyan la FPGA.

### C. Control del Servomotor como Ventilador
Un servomotor estándar controla la posición angular ($0^\circ$ a $180^\circ$) mediante una señal PWM de 50 Hz. No funciona como un ventilador de rotación continua a menos que:
1. Se modifique internamente para rotación continua (perdiendo control posicional).
2. Se utilice mecánicamente para **abrir o cerrar una compuerta o persiana de ventilación**.
* *Alternativa:* Si se requiere flujo de aire continuo (aspas de ventilador), es preferible un motor DC acoplado a un MOSFET controlado por variaciones de ciclo de trabajo (PWM).

---

## 3. Arquitectura Digital Propuesta (RTL Puro)

Para aprovechar la concurrencia real de la FPGA, el sistema se divide en módulos jerárquicos independientes sincronizados por un reloj maestro común ($CLK_{\text{sys}} = 50\text{ MHz}$).

```
                             +-----------------------+
                             |     FPGA Cyclone V    |
                             |                       |
+-------------+  Digital     +------------+          |
| Sensor Hum. |------------->| Driver Hum |---+      |
+-------------+              +------------+   |      |
                                              | Pulsos|   +------------+     +---------------+
+-------------+  I2C / SPI   +------------+   |Strobe |   |            |---->| Driver Valv.  |--> Electroválvula
| Sensor Temp |------------->| Driver Temp|`-->+----->|    FSM     |     +---------------+
+-------------+              +------------+   |       |  CENTRAL   |     +---------------+
                                              |       |            |---->| Driver Bomba  |--> Bomba
+-------------+  ADC SPI     +------------+   |       |            |     +---------------+
|  Sensor UV  |------------->| Driver UV  |---+       |            |     +---------------+
+-------------+              +------------+           |            |---->| Driver PWM    |--> Servomotor
                                                      +------------+     +---------------+
```

### Módulos Controladores (Drivers de Sensores)
Cada sensor cuenta con una entidad encargada exclusivamente del protocolo físico de comunicación. Su función es:
1. Muestrear el periférico a su tasa de refresco nativa.
2. Almacenar el dato binario en un registro interno.
3. Evaluar los umbrales críticos de control (ej. $\text{Humedad} < \text{Umbral Min}$).

### El Concepto de Señales "Strobe" (Eventos)
Para evitar bloqueos o sobre-reacciones en la FSM central, los drivers de los sensores no envían señales de nivel alto sostenido. En su lugar, emiten un **Strobe (pulso de un único ciclo de reloj del sistema)** cuando ocurre un cambio de estado válido o se alcanza un umbral crítico. Esto permite a la FSM tomar decisiones asíncronas de manera estructurada y síncrona con el clock principal.

---

## 4. Diseño de la FSM Central (Máquina de Estados Finitos)

La lógica de control principal se modela mediante una máquina de estados síncrona. A continuación se detallan los estados propuestos:

1. **`ST_IDLE` (Reposo):** Estado inicial. Apaga todos los actuadores hidráulicos. Limpia temporizadores. Espera la habilitación global del sistema.
2. **`ST_MONITOR` (Monitoreo Activo):** Evalúa los registros y pulsos provenientes de los módulos sensores de forma paralela.
   * *Transición a Riego:* Si se recibe el evento `humedad_baja` **Y** el sensor UV indica que no hay radiación extrema (evitando la evaporación inmediata del agua).
   * *Transición a Ventilación:* Si se recibe el evento `alta_temperatura`.
3. **`ST_RIEGO` (Control Hidráulico):** Activa la secuencia de apertura de la electroválvula y encendido de la bomba sumergible. Mantiene la operación activa mediante un temporizador en hardware (contador de ciclos) o hasta recibir el pulso `humedad_ok`.
4. **`ST_VENTILACION` (Control Térmico):** Modifica el ciclo de trabajo enviado al driver del servomotor/ventilador para mitigar la temperatura. Permanece en este estado hasta que el controlador térmico envíe un pulso de `temperatura_estable`.
5. **`ST_COOLDOWN` (Espera de Seguridad):** Introduce un retardo controlado en hardware tras finalizar un ciclo de riego o ventilación. Esto añade estabilidad al sistema, impidiendo oscilaciones de alta frecuencia (conmutación destructiva de relés) si los sensores fluctúan cerca del umbral de decisión.

---

## 5. Buenas Prácticas para la Implementación en VHDL/Verilog

* **Sincronización de Dominios de Reloj (Clock Domain Crossing):** Los sensores operan a frecuencias del orden de los kHz o Hz, mientras que la FSM opera a MHz. Cualquier señal externa o proveniente de un dominio de reloj lento debe pasar por un circuito **anti-rebote (debouncer)** y un **sincronizador de dos flip-flops** para mitigar la metaestabilidad.
* **Histéresis en Hardware:** Al evaluar umbrales numéricos (ej. Temperatura $> 30^\circ\text{C}$), se debe programar una ventana de histéresis. El sistema debe activar la alarma a los $30^\circ\text{C}$ pero desactivarla únicamente cuando descienda de los $28^\circ\text{C}$, eliminando el ruido de conmutación.
* **Reset Síncrono y Máquinas Seguras:** Asegurar que la FSM implemente un reset síncrono que fuerce el estado `ST_IDLE` de manera inmediata. Configurar Quartus para utilizar estilos de codificación seguros (*Safe State Machine*) para evitar estados huérfanos ante radiación o fallos eléctricos en la FPGA.
