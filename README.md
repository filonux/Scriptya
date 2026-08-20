<p align="center">
  <img src="assets/icon.png" width="96" alt="Icono de Scriptya">
</p>

<h1 align="center">Scriptya</h1>

<p align="center">
  Un menú para tus scripts: los organiza en carpetas, los ejecuta con búsqueda difusa,<br>
  y convierte cualquiera de ellos en una app de escritorio con su propio icono.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/bash-%3E%3D4.0-4EAA25?logo=gnubash&logoColor=white" alt="Bash 4+">
  <img src="https://img.shields.io/badge/Linux%20Mint-22.3%20Cinnamon-87CF3E?logo=linuxmint&logoColor=white" alt="Linux Mint 22.3 Cinnamon">
  <img src="https://img.shields.io/badge/licencia-GPLv3-blue" alt="Licencia GPLv3">
</p>

---

<img width="530" height="457" alt="Scryptya-menu" src="https://github.com/user-attachments/assets/1a030077-92df-4d7b-a249-2e7c1a3d3e80" />

-Nueva Función "Cambiar Icono": cambiar los iconos de los scripts que tengas instalados tantas veces como quieras. Puedes cambiar incluso el icono de Scriptya por el subido en este repositorio en lugar del genérico que utiliza al instalarse

<img width="652" height="439" alt="Scriptya-menu-nuevo-cambiar-icono" src="https://github.com/user-attachments/assets/b14c37f6-b133-4fe5-b797-38df1a1f5fa1" />


## El problema que resuelve

Ejecutar, instalar, desinstalar, actualizar tus scripts, historial completo, personalización de iconos, integración en menú.

Scriptya es un único fichero `.sh` sin dependencias obligatorias.

## Qué hace exactamente

- **Abre un menú navegable** sobre la carpeta de scripts que le indiques, respetando subcarpetas.
- **Busca mientras escribes**, con [`fzf`](https://github.com/junegunn/fzf) si lo tienes instalado; si no, cae a un menú numerado clásico donde también puedes teclear texto para filtrar.
- **Lee metadatos de cada script** (comentarios al principio del fichero) para decidir cómo mostrarlo y ejecutarlo: nombre bonito, descripción, si pide confirmación, si necesita `sudo`, si debe abrirse en una terminal nueva, en qué orden aparece y si necesita que le pases algún dato antes de arrancar.
- **Convierte un script en una app independiente**, con su propio icono, en el menú de aplicaciones de Cinnamon y/o en el Escritorio — sin que tengas que escribir un `.desktop` a mano. Si le das una imagen, la recorta y le quita el fondo automáticamente (con ImageMagick).
- **Guarda un historial** de cada ejecución: fecha, resultado y si usó `sudo`.
- **Deja cambiar la carpeta de scripts** en cualquier momento, navegando con un selector de carpetas (usa el diálogo nativo del sistema si tienes `zenity`).

## La ventaja

Añades esto encima de tu script y ya aparece bien integrado en el menú, con confirmación, con `sudo` si lo necesita, y como icono de escritorio si quieres:

```bash
#!/bin/bash
# MENU: Actualizar sistema
# DESCRIPTION: apt update, upgrade y autoremove
# CONFIRM: true
# TERMINAL: true
# SUDO: true

set -euo pipefail
apt update && apt upgrade -y && apt autoremove -y
```

El script sigue siendo un script normal: puedes ejecutarlo directamente (`./actualizar_sistema.sh`) sin pasar por Scriptya, y funciona igual. Los metadatos son opcionales y se ignoran si faltan.

## Instalación

```bash
git clone https://github.com/filonux/Scriptya.git
cd scriptya/script
chmod +x scriptya.sh
./scriptya.sh --install
```

El asistente te pregunta dónde están (o van a estar) tus scripts, si quieres un par de ejemplos de partida, y si quieres un acceso directo y/o entrada en el menú de aplicaciones. Al terminar, tendrás el comando `scriptya` disponible en cualquier terminal.

Si prefieres probarlo sin instalar nada en el sistema:

```bash
./scriptya.sh              # abre el menú directamente, tal cual está
./scriptya.sh --desktop    # o crea un acceso directo que ejecuta este mismo fichero
```

## Comandos

| Comando | Qué hace |
|---|---|
| `scriptya` | Abre el menú principal |
| `scriptya --install` | Instala en el sistema (comando `scriptya`, configuración, symlink) |
| `scriptya --desktop` | Crea un acceso directo que ejecuta este fichero tal cual, sin instalar nada |
| `scriptya --icons` | Asistente para convertir un script suelto en app independiente con icono |
| `scriptya --uninstall-icons` | Ver o desinstalar apps independientes ya creadas |
| `scriptya --update` | Actualiza la copia instalada con la versión actual del fichero |
| `scriptya --uninstall` | Desinstala todo lo creado por `--install` (tus scripts no se tocan) |
| `scriptya --version` | Muestra la versión |
| `scriptya --help` | Muestra la ayuda |

Estas mismas acciones ("Instalar Scripts", "Desinstalar Scripts", "Buscar Scripts", "Ver Historial") también están disponibles desde el propio menú, al final de la lista de la carpeta raíz.

## Metadatos disponibles

Van en las primeras líneas del script, justo después del `#!/bin/bash`, como comentarios. Todos son opcionales.

| Campo | Qué controla | Por defecto |
|---|---|---|
| `MENU` | Nombre que se muestra en el menú | nombre del fichero |
| `DESCRIPTION` | Descripción corta, debajo del nombre | (ninguna) |
| `CONFIRM` | `true` para pedir confirmación antes de ejecutar | `false` |
| `TERMINAL` | `true` para abrirlo en una terminal nueva, con notificación de escritorio al terminar | `false` |
| `SUDO` | `true` para ejecutarlo con `sudo` | `false` |
| `ORDER` | Número que decide el orden en el menú (menor va antes) | `500` |
| `ASK` | Pide un dato por teclado y se lo pasa como argumento (`$1`, `$2`...). Repetible | (ninguno) |
| `ICON` | Icono a usar con "Instalar Scripts": ruta a una imagen o nombre de icono del tema del sistema | selector al instalar |

Alternativa a `ORDER`: el orden alfabético ya lo respeta sin necesidad de metadato.

## Uso del día a día

- **Navegar y ejecutar**: entra en carpetas, ejecuta un script, vuelve atrás. Con `fzf` instalado escribes para filtrar en tiempo real; sin él, tecleas un número o un texto que filtra la lista.
- **Instalar Scripts**: elige un script del árbol, un icono (navegando por imágenes o escribiendo un nombre de icono del sistema) y dónde quieres el acceso — menú de Cinnamon, Escritorio, o ambos.
- **Desinstalar Scripts**: lista lo que has instalado como app independiente y te deja quitar uno, varios (separados por espacio) o todos.
- **Buscar Scripts**: cambia la carpeta de scripts activa, navegando con el selector nativo del sistema si tienes `zenity`.
- **Ver Historial**: las últimas ejecuciones, con fecha, resultado (✓/✗) y si usaron `sudo`. Se guarda en `~/.local/share/scriptya/history.log`.

## Compatibilidad

Probado en **Linux Mint 22.3 Cinnamon**. Al usar únicamente Bash, coreutils y el estándar de ficheros `.desktop` de freedesktop.org, debería funcionar igual en otras distros basadas en Ubuntu/Debian y otros entornos de escritorio (GNOME, XFCE, MATE...), aunque de momento solo está verificado en Mint/Cinnamon.

Dependencias opcionales — nada de esto es obligatorio, Scriptya funciona sin ellas, pero mejoran la experiencia:

| Herramienta | Para qué |
|---|---|
| `fzf` | Menú con búsqueda difusa en vez del menú numerado |
| `zenity` | Selector de carpetas/imágenes nativo del sistema |
| `imagemagick` | Ajuste automático de tamaño y transparencia al instalar un icono |
| `libnotify` (`notify-send`) | Notificación de escritorio cuando termina un script en terminal nueva |
| `xdg-user-dirs` | Detecta la carpeta de Escritorio real, sea cual sea el idioma del sistema |

## Sobre el idioma

Scriptya está en español: menús, ayuda, mensajes y comentarios. No hay versión en inglés todavía.

**Mini roadmap**, sujeto a que haya interés real:

- [ ] Traducción completa de menús, ayuda y mensajes al inglés
- [ ] Forma de elegir idioma (detección del sistema o flag `--lang`)
- [ ] Scripts de ejemplo también en inglés

Si te interesaría usarlo en inglés, dilo en un issue — es la señal que necesito para priorizarlo.

## Estructura del repositorio

```
scriptya/
├── LICENSE
├── README.md
├── script/
│   └── scriptya.sh
├── assets/
│   ├── icon.png        # icono de la app (usado arriba en este README)
│  
└── .github/
    ├── ISSUE_TEMPLATE/
    │   ├── bug_report.md
    │   └── feature_request.md
    ├── PULL_REQUEST_TEMPLATE.md
    ├── CONTRIBUTING.md
    ├── CODE_OF_CONDUCT.md
    └── SECURITY.md
```

## Contribuir

Los issues y pull requests son bienvenidos — hay plantillas en `.github/` para reportar errores, proponer mejoras, o enviar un PR. La guía completa está en [CONTRIBUTING.md](.github/CONTRIBUTING.md).

## Licencia

GPLv3. Consulta el fichero [LICENSE](LICENSE).

---

Hecho por **Filonux**.
