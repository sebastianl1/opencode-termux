# Politica de seguridad

OpenCode para Termux descarga y ejecuta el binario oficial de OpenCode en tu
dispositivo. La seguridad de ese proceso es nuestra prioridad.

## Reportar una vulnerabilidad

**NO abras un issue publico** para vulnerabilidades. Contacta a los mantenedores
en privado por el canal de GitHub Security Advisories o por correo a los
mantenedores del repositorio.

Incluye en tu reporte:

- Descripcion de la vulnerabilidad y su impacto.
- Pasos para reproducirla.
- Plataforma afectada (Termux/Android ARM64).
- Version de OpenCode/install.sh afectada.

## Consideraciones de seguridad del proyecto

- **Descargas solo HTTPS**: `install.sh` y `tools/update-mirror.sh` usan
  `curl --proto =https` con `--connect-timeout` y `--max-time`.
- **Verificacion al instalar**: `verify_installation()` comprueba que el
  binario se ejecuta correctamente antes de darlo por instalado.
- **Fallo seguro**: si la instalacion falla, se restaura el respaldo anterior
  (`~/backups/opencode`).
- **Multi-fuente**: vendor oficial → espejo propio → npm → termuxvoid, para no
  depender de un unico punto de fallo.
- **Sin secretos en el repositorio**: no se commitean tokens, API keys ni
  configuraciones personales. Reporta cualquier excepcion.

## Alcance

Este proyecto se distribuye SIN GARANTIA (licencia MIT). Usalo bajo tu
responsabilidad. El binario de OpenCode pertenece a sus autores originales.
