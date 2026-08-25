<p align="center">
  <img src="assets/icon.png" width="96" alt="Icono de Scriptya">
</p>

<h1 align="center">Scriptya</h1>

<p align="center">
  Un menú para tus scripts: los organiza en carpetas, los ejecuta con búsqueda difusa,<br>
  y convierte cualquiera de ellos en una app de escritorio con su propio icono.
</p>


<img width="655" height="530" alt="1menu-nuevo-scriptya" src="https://github.com/user-attachments/assets/68fae237-61dd-4732-8a69-d92647b3798d" />
<img width="654" height="531" alt="2metadatos-scriptya" src="https://github.com/user-attachments/assets/0acd3f7f-e2e1-4ec6-98c0-7e4400f82a66" />
<img width="653" height="531" alt="3integracion-nemo-scriptya" src="https://github.com/user-attachments/assets/7e2e232e-0415-4d05-81a3-81942721b86b" />
<img width="748" height="658" alt="4nemo-scriptya-clickdere" src="https://github.com/user-attachments/assets/20e5bb0f-9cca-4822-9300-61cbe8873570" />

* Update 25-08-2026. Nuevas Funciones: 
- "Insertar Metadatos": asistente que rellena MENU/DESCRIPTION/CONFIRM/TERMINAL/SUDO/ORDER/ICON/ASK en un script existente sin tocarlo a mano (y también los edita o los borra de golpe).
  
- Integración con Nemo: 4 acciones de botón derecho (Lanzar/Instalar/Desinstalar/Cambiar icono) en el explorador de Cinnamon, activable/desactivable, sin dejar rastro en el sistema.
  
- "Icono para HTML": dentro de "Cambiar Icono", da de alta una página web suelta como app independiente con su propio icono.
  
- "Cambiar Icono": cambiar los iconos de los scripts o programas cualquiera que tengas instalados tantas veces como quieras. Puedes cambiar incluso el icono de Scriptya por el subido en este repositorio en lugar del genérico que utiliza al instalarse, o el de [LinuxMint Scripter](https://github.com/filonux/LinuxMint-Scripter) por el oficial de su propio repositorio, para que quede igual de bien integrado en el menú y en el escritorio.

## El problema que resuelve

Ejecutar, instalar, desinstalar, actualizar tus scripts, meterles metadatos sin tocar el código, historial completo, personalización de iconos, integración en el menú de aplicaciones y en el explorador de archivos.

Scriptya es un único fichero `.sh` sin dependencias obligatorias.

## Qué hace exactamente

- **Abre un menú navegable** sobre la carpeta de scripts que le indiques, respetando subcarpetas.
- **Busca mientras escribes**, con [`fzf`](https://github.com/junegunn/fzf) si lo tienes instalado; si no, cae a un menú numerado clásico donde también puedes teclear texto para filtrar.
- **Lee metadatos de cada script** (comentarios al principio del fichero) para decidir cómo mostrarlo y ejecutarlo: nombre bonito, descripción, si pide confirmación, si necesita `sudo`, si debe abrirse en una terminal nueva, en qué orden aparece y si necesita que le pases algún dato antes de arrancar.
- **Te deja meter esos metadatos sin tocar el código**: un asistente ("Insertar Metadatos") los pregunta uno a uno — con el valor actual entre corchetes, para no perderlo si solo cambias uno — y los escribe al principio del script sin tocar el resto del fichero. También sirve para editarlos más tarde o para quitarlos todos de golpe.
- **Convierte un script (o una página HTML suelta) en una app independiente**, con su propio icono, en el menú de aplicaciones de Cinnamon y/o en el Escritorio — sin que tengas que escribir un `.desktop` a mano. Si le das una imagen, la ajusta a un icono cuadrado y, si detecta un fondo liso (el caso típico de un logo), se lo quita automáticamente (con ImageMagick).
- **Cambia el icono de cualquier programa instalado**: el de Scriptya, el de un script o página web que ya convertiste en app, o el de cualquier otra aplicación con entrada de menú — Firefox, GIMP, LibreOffice, venga de un `.deb`, un Flatpak o un Snap. Si es una app del sistema, el nuevo icono se guarda en una copia personal, sin tocar el original ni pedir contraseña.
- **Se integra con el botón derecho de Nemo** (el explorador de Cinnamon), si lo activas: añade acciones para lanzar, instalar, desinstalar o cambiar el icono de un script o página web directamente desde el explorador, sin tener que buscarlo antes en el menú de Scriptya. Vive entero en tu carpeta de usuario y se desactiva igual de fácil, sin dejar rastro en el sistema.
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

El script sigue siendo un script normal: puedes ejecutarlo directamente (`./actualizar_sistema.sh`) sin pasar por Scriptya, y funciona igual. Los metadatos son opcionales y se ignoran si faltan. Y si no te apetece escribirlos a mano, el propio menú trae un asistente ("Insertar Metadatos") que te los pregunta campo a campo y los guarda por ti.

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

Estas mismas acciones ("Instalar Scripts", "Desinstalar Scripts", "Cambiar Icono", "Insertar Metadatos", "Buscar Scripts", "Integración con Nemo" si la tienes instalada, "Ver Historial") también están disponibles desde el propio menú, al final de la lista de la carpeta raíz.

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
- **Desinstalar Scripts**: lista lo que has instalado como app independiente (scripts y páginas web) y te deja quitar uno, varios (separados por espacio) o todos.
- **Cambiar Icono**: el de Scriptya, el de un script o página web ya instalados, el de una página web nueva (le crea un acceso propio, como "Instalar Scripts" pero para HTML), o el de cualquier otro programa del sistema — eliges a quién y luego la imagen nueva, igual que al instalar.
- **Insertar Metadatos**: elige un script del árbol y rellena sus metadatos con un asistente — Intro para dejar cada campo igual, "-" para vaciarlo. Si el script ya tenía metadatos, te deja editarlos o quitarlos todos de golpe en vez de repetir la plantilla entera.
- **Buscar Scripts**: cambia la carpeta de scripts activa, navegando con el selector nativo del sistema si tienes `zenity`.
- **Integración con Nemo**: la activas o desactivas desde aquí. Activa, añade botón derecho en Nemo: sobre un `.sh` sin instalar, Lanzar e Instalar (ya instalado, Lanzar, Desinstalar y Cambiar icono); sobre un `.html`/`.htm` sin instalar, Cambiar icono e Instalar (ya instalado, Cambiar icono y Desinstalar). No toca nada del sistema — vive en `~/.local/share/nemo/actions` y se quita igual de fácil, sin dejar rastro.
- **Ver Historial**: las últimas ejecuciones, con fecha, resultado (✓/✗) y si usaron `sudo`. Se guarda en `~/.local/share/scriptya/history.log`.

## Compatibilidad

Probado en **Linux Mint 22.3 Cinnamon**. Al usar únicamente Bash, coreutils y el estándar de ficheros `.desktop` de freedesktop.org, debería funcionar igual en otras distros basadas en Ubuntu/Debian y otros entornos de escritorio (GNOME, XFCE, MATE...), aunque de momento solo está verificado en Mint/Cinnamon. La excepción es la integración con Nemo: solo tiene sentido si usas Nemo (el explorador de Cinnamon) en otro entorno de escritorio esa opción concreta no hace nada, pero el resto de Scriptya funciona igual.

Dependencias opcionales, nada de esto es obligatorio, Scriptya funciona sin ellas, pero mejoran la experiencia:

| Herramienta | Para qué |
|---|---|
| `fzf` | Menú con búsqueda difusa en vez del menú numerado |
| `zenity` | Selector de carpetas/imágenes nativo del sistema |
| `imagemagick` | Ajuste automático de tamaño y transparencia al instalar o cambiar un icono |
| `libnotify` (`notify-send`) | Notificación de escritorio cuando termina un script en terminal nueva |
| `xdg-user-dirs` | Detecta la carpeta de Escritorio real, sea cual sea el idioma del sistema |
| `libglib2.0-bin` (`gio`) | Marca los accesos directos nuevos como "de confianza", para que Nemo no pida permiso al abrirlos |
| `xdg-utils` (`xdg-open`) | Abre la página en el navegador al usar "Icono para HTML" |

## Sobre el idioma

Scriptya está en español: menús, ayuda, mensajes y comentarios. No hay versión en inglés todavía.

**Mini roadmap**, sujeto a que haya interés real:

- [ ] Traducción completa de menús, ayuda y mensajes al inglés
- [ ] Forma de elegir idioma (detección del sistema o flag `--lang`)
- [ ] Empaquetado en un .deb

Si te interesaría usarlo en inglés, dilo en un issue, apoya con estrellas, etc — es la señal que necesito para priorizarlo.
Cuanto más apoyo reciba el proyecto más cambios le iré incorporando.

## Contribuir

Los issues y pull requests son bienvenidos — hay plantillas en `.github/` para reportar errores, proponer mejoras, o enviar un PR. La guía completa está en [CONTRIBUTING.md](.github/CONTRIBUTING.md).

## Licencia

GPLv3. Consulta el fichero [LICENSE](LICENSE).

---

Hecho por **Filonux**.
