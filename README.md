# OptimizarPC

Suite de diagnostico, mantenimiento y optimizacion para Windows.

## Funciones
- Diagnostico de hardware y Windows
- Procesos y consumo de recursos
- Limpieza segura
- Programas de inicio
- Inventario de servicios
- Alto rendimiento
- Reparacion de red
- Puntos de restauracion
- Actualizaciones automaticas desde GitHub

## Actualizador
La aplicacion consulta update.json en main. Si aparece una version superior, el boton Buscar actualizaciones descarga el paquete, verifica SHA-256 cuando esta definido, cierra la app y ejecuta un actualizador separado que reemplaza los archivos y vuelve a abrir OptimizarPC.

## Ejecucion
Ejecuta Launch-PC-Optimizer.cmd. La primera ejecucion copia el programa a %LOCALAPPDATA%\OptimizarPC.
