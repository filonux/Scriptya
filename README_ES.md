<p align="center">
  <img src="assets/icon.png" width="140" alt="Icono de Scriptya">
</p>

<h1 align="center">Scriptya</h1>

<p align="center">
  Un menú para tus scripts: los organiza en carpetas, los ejecuta con búsqueda difusa,<br>
  y convierte cualquiera de ellos en una app de escritorio con su propio icono.
</p>

<p align="center"><strong><a href="README.md">Leer en inglés</a></strong></p>

<img width="655" height="530" alt="1menu-nuevo-scriptya" src="https://github.com/user-attachments/assets/68fae237-61dd-4732-8a69-d92647b3798d" />
<img width="654" height="531" alt="2metadatos-scriptya" src="https://github.com/user-attachments/assets/0acd3f7f-e2e1-4ec6-98c0-7e4400f82a66" />
<img width="653" height="531" alt="3integracion-nemo-scriptya" src="https://github.com/user-attachments/assets/7e2e232e-0415-4d05-81a3-81942721b86b" />
<img width="748" height="658" alt="4nemo-scriptya-clickdere" src="https://github.com/user-attachments/assets/20e5bb0f-9cca-4822-9300-61cbe8873570" />

*Actualización 10-09-2026. Novedades:*
- **Muchos más tipos de script**: además de Shell, Scriptya ahora descubre, ejecuta y gestiona scripts de Python, Node.js, Perl, Ruby, Lua, Fish, AWK, PHP y Go, además de páginas HTML independientes — todos con metadatos (nombre, descripción, confirmación, orden, icono y más), iconos personalizados e integración completa con el menú y con Nemo, igual que los scripts `.sh` originales.
- **Ahora Scriptya también gestiona páginas HTML**: ejecutarlas, convertirlas en apps independientes con icono propio, insertar o editar sus metadatos como comentarios HTML, y controlarlas desde Nemo — el mismo flujo que con cualquier otro tipo de script.
- **Guía completa en inglés**: el README en inglés está ahora completo, con la misma estructura que esta versión en español, sección por sección.
- "Insertar Metadatos": asistente que rellena MENU/DESCRIPTION/CONFIRM/TERMINAL/SUDO/ORDER/ICON/ASK en un script existente sin tocarlo a mano (y también los edita o los borra de golpe). Los metadatos también sirven para cambiar el nombre del acceso directo del escritorio y del menú automáticamente.
  
- Integración con Nemo: 4 acciones de botón derecho (Lanzar/Instalar/Desinstalar/Cambiar icono) en el explorador de Cinnamon, activable/desactivable, sin dejar rastro en el sistema.
  
- "Cambiar Icono": cambiar los iconos de los scripts o programas cualquiera que tengas instalados tantas veces como quieras. Puedes cambiar incluso el icono de Scriptya por el subido en este repositorio en lugar del genérico que utiliza al instalarse, o el de [LinuxMint Scripter](https://github.com/filonux/LinuxMint-Scripter) por el oficial de su propio repositorio, para que quede igual de bien integrado en el menú y en el escritorio.

## El problema que resuelve

Ejecutar, instalar, desinstalar, actualizar tus scripts, meterles metadatos sin tocar el código, historial completo, personalización de iconos, integración en el menú de aplicaciones y en el explorador de archivos.

Scriptya es un único fichero `.sh` sin dependencias obligatorias.

## Qué hace exactamente

- **Abre un menú navegable** sobre la carpeta de scripts que le indiques, respetando subcarpetas.
- **Busca mientras escribes**, con [`fzf`](https://github.com/junegunn/fzf) si lo tienes instalado; si no, cae a un menú numerado clásico donde también puedes teclear texto para filtrar.
- **Lee metadatos de cualquier fichero gestionado** (comentarios de Shell/Python/Perl/Ruby/Lua/Fish/AWK en `.sh`/`.py`/`.pl`/`.rb`/`.lua`/`.fish`/`.awk`, comentarios `//` en PHP, Node.js y Go, y comentarios HTML en `.html`/`.htm`) para decidir cómo mostrarlo y abrirlo: nombre, descripción, confirmación, orden en el menú e icono; los scripts pueden pedir `sudo`, una terminal nueva y datos antes de arrancar.
- **Te deja meter esos metadatos sin tocar el código**: un asistente ("Insertar Metadatos") los pregunta uno a uno — con el valor actual entre corchetes, para no perderlo si solo cambias uno — y los escribe al principio del fichero sin tocar el resto. En HTML los escribe como comentarios HTML y mantiene intacto el documento. También sirve para editarlos más tarde o para quitarlos todos de golpe.
- **Convierte scripts compatibles de Shell, Python, Node.js, Perl, Ruby, Lua, Fish, AWK, PHP CLI y Go, o páginas HTML independientes en apps**,  con su propio icono, en el menú de aplicaciones de Cinnamon y/o en el Escritorio — sin que tengas que escribir un `.desktop` a mano. Si le das una imagen, la ajusta a un icono cuadrado y, si detecta un fondo liso (el caso típico de un logo), se lo quita automáticamente (con ImageMagick).
- **Cambia el icono de cualquier programa instalado**: el de Scriptya, el de un script o página web que ya convertiste en app, o el de cualquier otra aplicación con entrada de menú — Firefox, GIMP, LibreOffice, venga de un `.deb`, un Flatpak o un Snap. Si es una app del sistema, el nuevo icono se guarda en una copia personal, sin tocar el original ni pedir contraseña.
- **Se integra con el botón derecho de Nemo** (el explorador de Cinnamon), si lo activas: añade acciones para lanzar, instalar, desinstalar o cambiar el icono de un script o página web directamente desde el explorador, sin tener que buscarlo antes en el menú de Scriptya. Vive entero en tu carpeta de usuario y se desactiva igual de fácil, sin dejar rastro.
- **Guarda un historial** de cada ejecución: fecha, resultado y si usó `sudo`.
- **Deja cambiar la carpeta de scripts** en cualquier momento, navegando con un selector de carpetas (usa el diálogo nativo del sistema si tienes `zenity`).
- **Incluye inglés y español**: en el primer arranque respeta `LC_ALL`, después `LC_MESSAGES` y después `LANG`. Los locales españoles usan español; cualquier otro locale cae por defecto en inglés. Puedes cambiarlo en cualquier momento con el comando de una sola letra `scriptya l` o con la opción `L)` del menú, y la elección se guarda en la configuración de Scriptya.

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

En un script Python, la misma idea usa comentarios normales de Python después del shebang:

```python
#!/usr/bin/env python3
# MENU: Informe local
# DESCRIPTION: Genera el informe diario
# CONFIRM: true
# TERMINAL: true
# SUDO: false
# ORDER: 20
# ICON: assets/report.png

print("Hola desde Python")
```

En un script Node.js, usa comentarios `//` normales después del shebang:

```javascript
#!/usr/bin/env node
// MENU: Herramienta local Node
// DESCRIPTION: Genera un informe local
// CONFIRM: true
// TERMINAL: true
// SUDO: false
// ORDER: 30
// ICON: assets/node.png

console.log("Hola desde Node.js");
```

En un script Perl, usa comentarios `#` normales después del shebang:

```perl
#!/usr/bin/env perl
# MENU: Utilidad Perl
# DESCRIPTION: Una pequeña utilidad Perl
# CONFIRM: false
# TERMINAL: true
# SUDO: false

print "Hola desde Perl\n";
```

En un script Ruby, usa comentarios `#` normales después del shebang:

```ruby
#!/usr/bin/env ruby
# MENU: Utilidad Ruby
# DESCRIPTION: Una pequeña utilidad Ruby
# CONFIRM: false
# TERMINAL: true
# SUDO: false

puts "Hola desde Ruby"
```

En un script Lua, usa comentarios `--` normales después del shebang:

```lua
#!/usr/bin/env lua
-- MENU: Utilidad Lua
-- DESCRIPTION: Una pequeña utilidad Lua
-- CONFIRM: false
-- TERMINAL: true
-- SUDO: false

print("Hola desde Lua")
```

En un script Fish, usa comentarios `#` normales después del shebang:

```fish
#!/usr/bin/env fish
# MENU: Utilidad Fish
# DESCRIPTION: Una pequeña utilidad Fish
# CONFIRM: false
# TERMINAL: false
# SUDO: false

echo "Hola desde Fish"
```

En un programa AWK, usa comentarios `#` normales al principio del fichero; los valores de `ASK` se exponen a través de `ENVIRON`:

```awk
# MENU: Utilidad AWK
# DESCRIPTION: Una pequeña utilidad AWK
# CONFIRM: false
# TERMINAL: false
# SUDO: false

BEGIN {
    print "Hola desde AWK"
}
```

En un script PHP CLI, usa comentarios `//` normales justo después de la etiqueta de apertura `<?php`:

```php
#!/usr/bin/env php
<?php
// MENU: Utilidad PHP
// DESCRIPTION: Una pequeña utilidad PHP
// CONFIRM: false
// TERMINAL: true
// SUDO: false

echo "Hola desde PHP\n";
```

En un fichero Go, usa comentarios `//` normales. Scriptya lo compila y lo ejecuta con Go:

```go
// MENU: Utilidad Go
// DESCRIPTION: Una pequeña utilidad Go
// CONFIRM: false
// TERMINAL: false
// SUDO: false
// ORDER: 40

package main

import "fmt"

func main() {
    fmt.Println("Hola desde Go")
}
```

En una página HTML, la misma idea usa comentarios HTML. Ponlos al principio del documento, después del `DOCTYPE` cuando exista:

```html
<!DOCTYPE html>
<!-- MENU: Panel local -->
<!-- DESCRIPTION: Panel útil sin conexión -->
<!-- CONFIRM: true -->
<!-- ORDER: 10 -->
<!-- ICON: assets/panel.png -->
<html>
```

Los ficheros Shell, Python, Node.js, Perl, Ruby, Lua, Fish, AWK, PHP CLI y Go aparecen en Scriptya y se lanzan con su intérprete; los ficheros Go se compilan y se ejecutan con Go; los ficheros `.html` y `.htm` aparecen en Scriptya y, al lanzarlos, abren esos mismos ficheros con el navegador predeterminado. Con `scriptya --icons` también puedes convertirlo en una aplicación independiente usando esos mismos metadatos.

El script sigue siendo un script normal: puedes ejecutarlo directamente (`./actualizar_sistema.sh`, `python3 informe.py` o `go run herramienta.go`) sin pasar por Scriptya, y funciona igual. Los metadatos son opcionales y se ignoran si faltan. Y si no te apetece escribirlos a mano, el propio menú trae un asistente ("Insertar Metadatos") que te los pregunta campo a campo y los guarda por ti.

## Instalación

```bash
git clone https://github.com/filonux/Scriptya.git
cd Scriptya/script
./scriptya.sh --install
```

El asistente te pregunta dónde están (o van a estar) tus scripts, si quieres un par de scripts de ejemplo de partida, y si quieres un acceso directo y/o entrada en el menú de aplicaciones. Al terminar, tendrás el comando `scriptya` disponible en cualquier terminal.

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
| `scriptya --icons` | Asistente para convertir un script o página HTML sueltos en app independiente con icono |
| `scriptya --uninstall-icons` | Ver o desinstalar apps independientes ya creadas |
| `scriptya --update` | Actualiza la copia instalada con la versión actual del fichero |
| `scriptya --uninstall` | Desinstala todo lo creado por `--install` (tus scripts no se tocan) |
| `scriptya --version` | Muestra la versión |
| `scriptya --help` | Muestra la ayuda |
| `scriptya l` | Intercambia Español / Inglés y guarda la preferencia |

Estas mismas acciones ("Instalar Scripts", "Desinstalar Scripts", "Cambiar Icono", "Insertar Metadatos", "Buscar Scripts", "Integración con Nemo" si la tienes instalada, "Ver Historial") también están disponibles desde el propio menú, al final de la lista de la carpeta raíz.

## Metadatos disponibles

Son opcionales y van al principio de cualquier fichero gestionado. En los `.sh`, `.py`, `.pl`, `.rb`, `.lua`, `.fish` y `.awk`, justo después del shebang, como comentarios. En AWK, los valores de `ASK` quedan disponibles como `SCRIPTYA_ASK_1`, `SCRIPTYA_ASK_2`, etc. En PHP, justo después de `<?php`, usando `//`; también se leen metadatos antiguos escritos con `#`. En Node.js (`.js`/`.mjs`/`.cjs`), usa `//` después del shebang. En `.html`/`.htm`, como comentarios HTML al principio del documento (después del `DOCTYPE` cuando exista).

En HTML, Scriptya usa `MENU`, `DESCRIPTION`, `CONFIRM`, `ORDER` e `ICON`. En `.sh`, `.py`, `.pl`, `.rb`, `.lua`, `.fish`, `.awk`, `.go`, PHP y Node.js, se pueden usar todos los campos, incluidos `TERMINAL`, `SUDO` y `ASK`.

Ejemplo de cabecera HTML:

```html
<!DOCTYPE html>
<!-- MENU: Panel local -->
<!-- DESCRIPTION: Panel útil sin conexión -->
<!-- CONFIRM: true -->
<!-- ORDER: 10 -->
<!-- ICON: assets/panel.png -->
<html>
```

Los ficheros `.sh`, `.py`, `.js`, `.mjs`, `.cjs`, `.pl`, `.rb`, `.lua`, `.fish`, `.awk`, `.php`, `.go`, `.html` y `.htm` que pongas directamente en la carpeta de scripts configurada, o dentro de sus subcarpetas, aparecen en el árbol de Scriptya. Los `.py` se lanzan con Python 3 (o con su shebang Python si tienen permiso de ejecución); los Node.js se lanzan con `node` (o con su shebang Node.js si tienen permiso de ejecución); los Perl se lanzan con `perl` (o con su shebang Perl si tienen permiso de ejecución); los Ruby se lanzan con `ruby` (o con su shebang Ruby si tienen permiso de ejecución); los Lua se lanzan con `lua` (o con su shebang Lua si tienen permiso de ejecución); los Fish se lanzan con `fish` (o con su shebang Fish si tienen permiso de ejecución); los AWK se lanzan con `awk -f`; los PHP se lanzan con `php` (o con su shebang PHP si tienen permiso de ejecución); los Go se compilan y ejecutan con Go; los HTML se abren con el navegador predeterminado. Con `scriptya --icons` también puedes instalar esa página como aplicación independiente usando su nombre, descripción e icono de los metadatos.

| Campo | Qué controla | Por defecto |
|---|---|---|
| `MENU` | Nombre que se muestra en el menú | nombre del fichero |
| `DESCRIPTION` | Descripción corta, debajo del nombre | (ninguna) |
| `CONFIRM` | `true` para pedir confirmación antes de ejecutar | `false` |
| `TERMINAL` | `true` para abrirlo en una terminal nueva, con notificación de escritorio al terminar | `false` |
| `SUDO` | `true` para ejecutarlo con `sudo` | `false` |
| `ORDER` | Número que decide el orden en el menú (menor va antes) | `500` |
| `ASK` | Pide un dato por teclado. Repetible; en scripts se pasa como argumento y en AWK queda como `SCRIPTYA_ASK_1`, `SCRIPTYA_ASK_2`, etc. | (ninguno) |
| `ICON` | Icono a usar con "Instalar Scripts": ruta a una imagen o nombre de icono del tema del sistema | selector al instalar |

Alternativa a `ORDER`: los scripts que no lo usan ya se ordenan alfabéticamente entre sí, así que ponerle un prefijo numérico al nombre del fichero (`01_backup.sh`, `02_limpiar.sh`) te da control total sobre el orden sin necesidad de meter metadatos.

## Uso del día a día

- **Navegar y ejecutar**: entra en carpetas, ejecuta un script, vuelve atrás. Con `fzf` instalado escribes para filtrar en tiempo real; sin él, tecleas un número o un texto que filtra la lista.
- **Instalar Scripts**: elige un `.sh`, `.py`, `.pl`, `.rb`, `.lua`, `.fish`, `.awk`, `.go`, Node.js (`.js`/`.mjs`/`.cjs`), PHP (`.php`) o página HTML del árbol, un icono (navegando por imágenes o escribiendo un nombre de icono del sistema) y dónde quieres el acceso — menú de Cinnamon, Escritorio, o ambos.
- **Desinstalar Scripts**: lista lo que has instalado como app independiente (scripts y páginas web) y te deja quitar uno, varios (separados por espacio) o todos.
- **Cambiar Icono**: el de Scriptya, el de un script o página web ya instalados, el de una página web nueva (le crea un acceso propio, como "Instalar Scripts" pero para HTML), o el de cualquier otro programa del sistema — eliges a quién y luego la imagen nueva, igual que al instalar.
- **Insertar Metadatos**: elige un `.sh`, `.py`, `.pl`, `.rb`, `.lua`, `.fish`, `.awk`, `.go`, Node.js (`.js`/`.mjs`/`.cjs`), PHP (`.php`) o página HTML del árbol y rellena sus metadatos con un asistente — Intro para dejar cada campo igual, `-` para vaciarlo. En HTML, los escribe como comentarios HTML y mantiene intacto el cuerpo del documento. Si el fichero ya tenía metadatos, te deja editarlos o quitarlos todos de golpe en vez de repetir la plantilla entera.
- **Buscar Scripts**: cambia la carpeta de scripts activa, navegando con el selector nativo del sistema si tienes `zenity`.
- **Integración con Nemo**: la activas o desactivas desde aquí. Activa, añade botón derecho en Nemo: sobre un `.sh`, `.py`, `.pl`, `.rb`, `.lua`, `.fish`, `.awk`, `.go`, PHP (`.php`) o Node.js (`.js`/`.mjs`/`.cjs`) sin instalar, Lanzar e Instalar (ya instalado, Lanzar, Desinstalar y Cambiar icono); sobre un `.html`/`.htm` sin instalar, Cambiar icono e Instalar (ya instalado, Cambiar icono y Desinstalar). No toca nada del sistema — vive en `~/.local/share/nemo/actions` y se quita igual de fácil, sin dejar rastro.
- **Ver Historial**: las últimas ejecuciones, con fecha, resultado (✓/✗) y si usaron `sudo`. Se guarda en `~/.local/share/scriptya/history.log`.
- **Idioma**: en el primer arranque la interfaz sigue el locale del sistema, cae por defecto a inglés cuando el locale no es español y se puede cambiar al instante con `scriptya l` o con la opción `L)` del menú. La elección manual se guarda en `~/.config/scriptya/config.conf`.

## Suite de demo

El repositorio incluye [`examples/`](examples/) con ejemplos seguros de todos los tipos de fichero soportados, además de casos específicos para confirmación, ASK, iconos, edición de metadatos y códigos de salida distintos de cero. Inicia Scriptya y apunta la carpeta de scripts a `examples/scripts` para probarlos desde el menú normal.

La demo tiene su propia [guía en inglés](examples/README.md) y [guía en español](examples/README_ES.md). Cada ejemplo está pensado para lanzarlo, instalarlo, desinstalarlo, ponerle un icono, editarlo con **Insertar Metadatos** y probarlo desde Nemo cuando esa integración esté activa.

## Compatibilidad

Probado en **Linux Mint 22.3 Cinnamon**. Al usar únicamente Bash, coreutils y el estándar de ficheros `.desktop` de freedesktop.org, debería funcionar igual en otras distros basadas en Ubuntu/Debian y otros entornos de escritorio (GNOME, XFCE, MATE...), aunque de momento solo está verificado en Mint/Cinnamon. La excepción es la integración con Nemo: solo tiene sentido si usas Nemo (el explorador de Cinnamon); en otro entorno de escritorio esa opción concreta no hace nada, pero el resto de Scriptya funciona igual.

Dependencias opcionales, nada de esto es obligatorio, Scriptya funciona sin ellas, pero mejoran la experiencia:

| Herramienta | Para qué |
|---|---|
| `fzf` | Menú con búsqueda difusa en vez del menú numerado |
| `zenity` | Selector de carpetas/imágenes nativo del sistema |
| `imagemagick` | Ajuste automático de tamaño y transparencia al instalar o cambiar un icono |
| `libnotify` (`notify-send`) | Notificación de escritorio cuando termina un script en terminal nueva |
| `xdg-user-dirs` | Detecta la carpeta de Escritorio real, sea cual sea el idioma del sistema |
| `python3` | Necesario para ejecutar `.py` que no tengan permiso de ejecución (normalmente ya está instalado) |
| `node` | Necesario para ejecutar ficheros `.js`/`.mjs`/`.cjs` sin un shebang Node.js ejecutable |
| `perl` | Necesario para ejecutar ficheros `.pl` sin un shebang Perl ejecutable |
| `ruby` | Necesario para ejecutar ficheros `.rb` sin un shebang Ruby ejecutable |
| `lua` | Necesario para ejecutar ficheros `.lua` sin un shebang Lua ejecutable |
| `fish` | Necesario para ejecutar ficheros `.fish` sin un shebang Fish ejecutable |
| `awk` | Necesario para ejecutar ficheros `.awk` |
| `php` | Necesario para ejecutar ficheros `.php` sin un shebang PHP ejecutable |
| `go` | Necesario para ejecutar ficheros `.go` |
| `libglib2.0-bin` (`gio`) | Marca los accesos directos nuevos como "de confianza", para que Nemo no pida permiso al abrirlos |
| `xdg-utils` (`xdg-open`) | Abre las páginas HTML en el navegador predeterminado al ejecutarlas o usar "Icono para HTML" |

## Sobre el idioma

Scriptya incluye ahora una interfaz completa en inglés y español: menús, ayuda, mensajes y acciones de Nemo generadas quedan traducidos. Los comentarios del código se mantienen en su idioma original para no hacer crecer el proyecto innecesariamente.

En el primer arranque, el idioma sigue `LC_ALL`, después `LC_MESSAGES` y después `LANG`. Un locale español (`es_*`, o las formas equivalentes habituales) selecciona español. Cualquier otro locale selecciona inglés. Cuando cambias manualmente, la preferencia se guarda en la configuración de Scriptya y permanece hasta que vuelvas a cambiarla.

La forma más rápida de cambiarlo es:

```bash
scriptya l
```

El mismo cambio está disponible como `L)` en el menú principal.

## Pruebas

El proyecto incluye una batería de pruebas Bash enfocada en [`tests/test_scriptya.sh`](tests/test_scriptya.sh). Comprueba sintaxis, permisos de ejecución, precedencia real de locales, cobertura de traducciones incluidos los errores, persistencia del idioma manual, compatibilidad con configuraciones antiguas, entradas de confirmación en ambos idiomas, localización de las acciones de Nemo, cambio de idioma por CLI y comprobaciones de humo del formato del terminal. Está pensada para no depender de herramientas opcionales como `fzf`, `zenity`, ImageMagick o Nemo.

Se ejecuta con:

```bash
chmod +x tests/test_scriptya.sh
./tests/test_scriptya.sh
```

## Contribuir

Los issues y pull requests son bienvenidos — hay plantillas en `.github/` para reportar errores, proponer mejoras, o enviar un PR. La guía completa está en [CONTRIBUTING.md](.github/CONTRIBUTING.md).

## Licencia

GPLv3. Consulta el fichero [LICENSE](LICENSE.txt).

---

Hecho por **[Filonux](https://github.com/filonux)**.
