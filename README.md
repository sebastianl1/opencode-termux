# OpenCode — Termux

<p align="center">
  <img src="imagenes/opencode-banner.jpg" alt="OpenCode CLI" width="600">
</p>

Instalacion nativa de **OpenCode** en Termux para Android ARM64.
Sin proot, sin VMs, sin Cloud Shell.

Este proyecto utiliza npm para instalar el paquete
[opencode-ai](https://www.npmjs.com/package/opencode-ai)
directamente en Termux de forma nativa.

---

## Requisitos

- **Termux** instalado desde [F-Droid](https://f-droid.org/packages/com.termux/)
  (no desde Google Play)
- **Dispositivo Android ARM64** (aarch64)
- **Conexion a internet** para descargar paquetes npm
- Espacio libre: ~200MB

---

## Instalacion

```bash
# Clonar el repositorio
git clone https://github.com/sebastianl1/opencode-termux.git
cd opencode-termux

# Ejecutar el instalador
bash install.sh
```

El instalador es interactivo y te guiara paso a paso:

1. Verifica el entorno (Termux, arquitectura, Node.js)
2. Instala Node.js si es necesario
3. Instala OpenCode via npm
4. Verifica la instalacion
5. Te muestra los proximos pasos para configurar un proveedor de IA

---

## Que instala

| Componente | Ruta | Descripcion |
|------------|------|-------------|
| `opencode` | `$PREFIX/bin/opencode` | Binario de OpenCode (via npm) |
| `opencode-ai` | `$PREFIX/lib/node_modules/opencode-ai` | Paquete npm |
| `~/.config/opencode/` | Directorio de usuario | Configuracion de OpenCode |

### Como funciona

OpenCode se ejecuta de forma nativa en Termux a traves de Node.js:

- **Sin proot** — No necesita contenedores ni emulacion
- **Sin glibc** — Usa la libc nativa de Android (Bionic) a traves de Node.js
- **Sin Cloud Shell** — Corre directamente en tu dispositivo
- **Nativo ARM64** — Optimizado para arquitectura aarch64

---

## Uso

### Iniciar OpenCode

```bash
opencode
```

### Verificar version

```bash
opencode --version
```

### Ver ayuda

```bash
opencode --help
```

### Actualizar

```bash
opencode upgrade
```

### Comandos principales

| Comando | Descripcion |
|---------|-------------|
| `opencode` | Iniciar la CLI interactiva |
| `opencode --version` | Mostrar version |
| `opencode --help` | Mostrar ayuda |
| `opencode upgrade` | Actualizar a la ultima version |
| `opencode auth login` | Autenticar con un proveedor de IA |

---

## Configuracion de proveedores

OpenCode necesita un proveedor de IA para funcionar. Despues de instalar,
configura tu proveedor preferido:

```bash
opencode auth login
```

Sigue las instrucciones en pantalla para autenticar con:
- **Google** (Gemini)
- **OpenAI** (GPT)
- **Anthropic** (Claude)
- **GitHub Copilot**
- O cualquier proveedor compatible con OpenCode

---

## Desinstalacion

Para desinstalar opencode:

```bash
bash install.sh --uninstall
```

Esto elimina el paquete npm y ofrece eliminar la configuracion.
Para eliminar los respaldos manualmente:

```bash
rm -rf ~/backups/opencode
```

---

## Estructura del proyecto

```
opencode-termux/
├── imagenes/
│   └── opencode-banner.jpg   # Banner del proyecto
├── install.sh                # Script de instalacion
├── README.md                 # Este archivo
└── LICENSE                   # Licencia MIT
```

---

## Autor

**Sebastian Laguna** — Creador y mantenedor del proyecto

---

## Licencia

Este proyecto esta bajo la licencia MIT. Ver el archivo [LICENSE](LICENSE).
