# Changelog

Todas las versiones notables de OpenCode para Termux se documentan aqui.
Formato basado en [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Fixed
- `install.sh`: verifica que el cargador glibc (`$PREFIX/glibc/lib/ld-linux-aarch64.so.1`)
  exista tras instalar la capa glibc; diagnostica con la ruta exacta si falta.
- `install.sh`: si la compilación del launcher C falla (p. ej. `cc`/`lld` crashea por
  tagged pointers de Android en algunos dispositivos), instala un launcher wrapper
  equivalente (bash + `exec` del cargador glibc) para que la verificación no falle.
- `install.sh`: valida que el binario descargado sea un ELF ARM64 real antes de
  aceptarlo; si es inválido (descarga corrupta, arquitectura equivocada), descarta
  la fuente y prueba la siguiente (vendor -> espejo -> npm -> termuxvoid).
- `install.sh`: verificación final ahora muestra el exit code y la salida real de
  `opencode --version` con diagnóstico, en vez del mensaje genérico.
- **Capa glibc**: crea un directorio `glibc-runtime` con symlinks a las librerias
  reales versionadas (`.so.6`) y corrige los `.so` planos que en la capa glibc son
  scripts de enlazado ASCII (p. ej. `libc.so`). El launcher usa
  `--library-path glibc-runtime:glibc/lib` para que el cargador no aborte con
  `invalid ELF header` al buscar `libc.so`.

### Added
- `install.sh --diagnose`: muestra entorno, launcher, DT_NEEDED del binario real,
  estado de las libs glibc (incluido el shim `glibc-runtime`) y la resolucion del
  cargador, con prueba directa `--version`. Sin cambiar nada.
- CI/CD: workflow de lint (bash -n, shellcheck, node --check lang, validacion
  i18n y descargas https) y job de tests (pytest).
- CD: workflow de despliegue de GitHub Pages (docs/).
- Tests (`tests/`) para i18n y para el instalador (https + `set -e`).
- `docs/llms.txt` (AEO) y `sitemap.xml` corregido.
- Documentacion de comunidad: `SECURITY.md`, `CONTRIBUTING.md`,
  `CODE_OF_CONDUCT.md` y este `CHANGELOG.md`.
- `.gitignore` raiz.

### Security
- `install.sh`: descargas con `--proto =https` (vendor, npm y fuentes).

### Fixed
- `README.md`: nombre del banner corregido (`opencode.jpg`) y arbol del
  proyecto incluye `docs/`.

## [1.3.0] - 2026-07

- Instalador v1.3 con launcher nativo, multi-fuente y espejo.

## [1.2.0] - 2026-07

- Banner del proyecto renombrado (`opencode.jpg`).

## [1.1.0] - 2026-07

- Ajuste menor en el instalador.

## [1.0.0] - 2026-07

- Instalador inicial de OpenCode para Termux.
