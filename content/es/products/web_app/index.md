---
sidebar_position: 2
title: 📱Aplicación web
layout: products
---

La aplicación web de Gratheon ayuda a los apicultores a gestionar [los datos de sus apiarios](free-tier/apiary-management.md), comunicarse con los dispositivos modulares instalados en las colmenas, analizar imágenes de cuadros y fondos sanitarios, almacenar [telemetría de series temporales](pro-tier/hive-telemetry-storage.md), generar [alertas](flexible-tier/alerts.md), elaborar previsiones y recibir sugerencias de IA para resolver problemas.

`status`: [TRL 6](https://www.nasa.gov/directorates/somd/space-communications-navigation-program/technology-readiness-levels/)

## Entidades principales del dominio

| Entidad | Descripción | Propiedades clave |
|--------|-------------|----------------|
| **Apiario** | Conjunto de colmenas situadas en una misma ubicación. Su tamaño está limitado por el terreno circundante que las abejas pueden polinizar. | Ubicación (latitud/longitud), nombre, estado activo |
| **Colmena** | Estructura física con secciones verticales. Puede dividirse, fusionarse o marcarse como colapsada. | Nombre, color, estado, cajas, colonia, historial de divisiones/fusiones, seguimiento del colapso |
| **Familia (colonia/reina)** | Superorganismo formado por abejas y dirigido por una reina que pone huevos. | Raza (variedad de Apis mellifera), año de incorporación, edad (calculada automáticamente), tratamientos |
| **Caja (sección de la colmena)** | Sección hueca de madera que aloja cuadros. Tipos: cámara de cría, alza de miel, piquera, ventilación, excluidor de reina, alimentador horizontal y fondo sanitario. | Tipo, posición, color, cuadros |
| **Cuadro** | Marco de madera con cera dentro de una sección. Tipos: lámina de cera, panal vacío, hueco, partición y alimentador. | Tipo, posición, caras izquierda/derecha |
| **Cara del cuadro** | Una cara del cuadro donde se pueden subir fotografías para analizarlas mediante IA. | Referencias de archivos de imagen, recursos detectados |
| **Inspección** | Instantánea del estado completo de la colmena durante una intervención del apicultor. Almacena en JSON la composición de la colmena en un momento determinado. | ID de colmena, datos (JSON), marca de tiempo |
| **Tratamiento** | Intervenciones químicas contra la varroa registradas por familia, caja o colmena para mantener el historial sanitario. | Tipo, marca de tiempo, objetivo (colmena/caja/familia) |
| **Archivo** | Imágenes subidas, como fotografías de cuadros o del fondo sanitario con varroa. Se procesan mediante el flujo de detección por IA. | Hash, dimensiones, ID de usuario, tipo de archivo, trabajos de detección |
| **Recursos detectados** | Tipos de celdas detectados mediante IA en fotografías de cuadros: cría operculada, huevos, miel, larvas, néctar, polen y otros. | Clase, coordenadas (x,y), radio, probabilidad |
| **Abejas/reinas detectadas** | Posiciones de abejas y reinas detectadas mediante IA en los cuadros. | Cuadros delimitadores, niveles de confianza |
| **Varroa detectada** | Ácaros varroa detectados mediante IA en fotografías del fondo sanitario. | Recuento, posiciones (próximamente) |
| **Métricas (telemetría)** | Datos de series temporales procedentes de sensores en dispositivos IoT. | Temperatura (°C), humedad (%), peso (kg), marca de tiempo |
| **Movimiento en la piquera** | Análisis del tráfico de abejas a partir de cámaras de vídeo situadas en la entrada. | Abejas que entran/salen, flujo neto, estadísticas de velocidad, abejas inmóviles, interacciones |
| **Alerta** | Avisos generados a partir de reglas y umbrales aplicados a las métricas. | Texto, tipo/valor de la métrica, ID de colmena, estado de entrega, marca de tiempo |
| **Regla de alerta** | Condiciones definidas por el usuario que activan alertas. | Tipo de métrica, condición, umbral, duración, estado activo, alcance (colmena/apiario) |
| **Canal de alerta** | Métodos de entrega de las alertas. | Tipo (correo electrónico/teléfono/Telegram), datos de contacto, franja horaria, estado activo |

![](../../about/img/web-app.png)

## Principales casos de uso de la aplicación
Un caso de uso agrupa funciones que, combinadas, aportan un gran valor al cliente.

### Subir fotografías para obtener estadísticas generales de la colonia
- Crea una colmena.
- Abre una sección concreta y añade cuadros.
- Abre un cuadro concreto y haz clic en «subir foto del cuadro» con las abejas y las celdas del panal visibles. Consulta la [gestión de las caras de los cuadros](free-tier/frame-side-management.md) y la [gestión de inspecciones](hobbyist-tier/inspection-management.md).
- Espera a que el backend procese la imagen.
- Obtén estadísticas asistidas por IA sobre el número de abejas y la distribución de las celdas.
- Compara distintas colmenas para saber cuáles son más fuertes a partir de datos reales.

### Seguir el desarrollo de la colonia a lo largo del tiempo
- Sigue los pasos para añadir fotografías de los cuadros de la colmena después de una inspección.
- Haz clic en el botón «Crear inspección» para guardar una instantánea temporal de la colmena.
- Comprueba que la nueva inspección aparezca en la pestaña Inspecciones.
	- Observa cómo cambia la distribución de los recursos entre las inspecciones a lo largo del tiempo.

### Enviar telemetría de peso desde sensores IoT
- Genera un token de API en la configuración de la cuenta.
- Enciende el dispositivo de sensores IoT y sigue la [documentación de los sensores de colmena](../../docs/beehive-sensors/beehive-sensors.md) para conectarlo a la red Wi-Fi y enviar datos.
- Abre la colmena correspondiente, entra en la pestaña Métricas y consulta los gráficos de peso y temperatura.
- Abre la pestaña Análisis para consultar datos de intervalos temporales concretos y relacionarlos con otra información, como el tiempo meteorológico.

### Transmitir vídeo desde la piquera
- Configura una cámara [Entrance Observer](../entrance_observer/entrance_observer.md) para transmitir vídeo.
- Comprueba que la transmisión de vídeo sea visible.

### Supervisar la varroa mediante el fondo sanitario
- Añade un fondo sanitario a la colmena.
- Sube una fotografía de la bandeja blanca extraíble en la que se vean los ácaros varroa.
- Las imágenes se versionan junto con las inspecciones para conservar un historial.
- El [recuento de varroa en el fondo sanitario](starter-tier/hive-bottom-varroa-count.md) proporcionará el número de ácaros y recomendaciones de tratamiento.



