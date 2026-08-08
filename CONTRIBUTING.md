# Contribuyendo a OpenCode para Termux

Gracias por querer contribuir. Este proyecto es open source (MIT) y su objetivo
es instalar OpenCode de forma nativa en Termux para Android ARM64.

## Formas de contribuir

- **Reportar bugs**: abre un issue describiendo el problema, tu dispositivo
  (SoC, RAM, version de Termux) y los pasos para reproducirlo.
- **Sugerir mejoras**: issues o PRs con propuestas claras.
- **Traducir**: la landing (`docs/lang/`) y el contenido del README.
- **Mantener el espejo**: si el vendor publica una version nueva, ejecuta
  `bash tools/update-mirror.sh` para actualizar el espejo.
- **Escribir codigo**: sigue las convenciones del proyecto.

## Flujo de trabajo

1. Haz fork y crea una rama: `git checkout -b feat/mi-mejora`.
2. Haz cambios pequenos y enfocados.
3. Verifica que todo pase (mismo conjunto que el CI de `.github/workflows/ci.yml`):
   ```bash
   bash -n install.sh tools/update-mirror.sh
   for f in docs/lang/*.js; do node --check "$f"; done
   python3 -m pytest tests/ -q
   ```
4. Envia el PR describiendo que hace y como probarlo.

## Tests

- Los tests viven en `tests/` y cubren la completitud de claves i18n y que el
  instalador use `set -e` y descargas solo HTTPS.
- Si tocas `install.sh`, `launcher.c` o `tools/update-mirror.sh`, ejecuta
  `python3 -m pytest tests/ -q` antes de enviar el PR.

## Convenciones

- Sin comentarios en el codigo salvo que aporten valor.
- Shebangs de Termux: `#!/data/data/com.termux/files/usr/bin/bash`.
- El launcher C se compila en la instalacion (`cc -O2 -DPREFIX=...`).
- Commits estilo Conventional Commits: `feat:`, `fix:`, `docs:`, `refactor:`, `chore:`.
- Finales de linea LF (no CRLF).
- El autor de los commits: `Sebastian Laguna <sebasbele11@gmail.com>`.

## Reportes de seguridad

Lee `SECURITY.md`. Para vulnerabilidades, NO abras un issue publico;
contacta a los mantenedores en privado.
