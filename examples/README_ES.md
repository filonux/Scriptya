# Demo de Scriptya

[English](README.md)

Conjunto compacto y seguro de ejemplos para comprobar los tipos de fichero y flujos principales de Scriptya. Son locales: muestran resultados deterministas, abren una única página HTML autocontenida o devuelven un error documentado.

## Ejemplos

| Fichero | Cobertura principal |
|---|---|
| `01-shell-demo.sh` | Shell, metadatos, icono y argumentos |
| `02-python-demo.py` | Python, shebang, metadatos y argumentos |
| `03-node-demo.js` | Node.js, shebang, metadatos `//` y argumentos |
| `04-perl-demo.pl` | Perl, modo estricto, metadatos y argumentos |
| `05-ruby-demo.rb` | Ruby, metadatos y argumentos |
| `06-lua-demo.lua` | Lua, shebang, metadatos y argumentos |
| `07-fish-demo.fish` | Fish, shebang, metadatos y argumentos |
| `08-html-demo.html` | Detección HTML, metadatos, icono y navegador |
| `09-confirm-and-ask.sh` | `CONFIRM` más dos valores `ASK` |
| `10-failure.sh` | Código de salida `7` e historial |
| `11-php-demo.php` | PHP CLI, posición de `<?php`, `ASK` |
| `12-awk-demo.awk` | AWK, metadatos y `ASK` mediante `ENVIRON` |
| `13-go-demo.go` | Compilación y ejecución de Go, metadatos y `ASK` |

`demo-blue.svg` y `demo-green.svg` son iconos locales pequeños. Incluyen título SVG para seguir siendo comprensibles fuera de Scriptya.

## Ejemplos vistosos

Un segundo conjunto, más visual, para los lenguajes más habituales. Mismas reglas de seguridad que arriba (sin `SUDO`, sin `TERMINAL`, sin red, sin escribir ficheros), pero centrado en el aspecto visual — un panel con caja, un pequeño gráfico de barras, una barra de progreso o una página HTML más elaborada — en vez de los simples tokens `_OK` que usa el conjunto mínimo para comprobaciones automáticas.

| Fichero | Cobertura principal |
|---|---|
| `14-shell-showcase-demo.sh` | Panel en caja, tabla pequeña, barra de progreso ANSI |
| `15-python-showcase-demo.py` | Banner en caja, gráfico de barras, barra de progreso (solo librería estándar) |
| `16-node-showcase-demo.js` | Banner en caja, gráfico de barras, barra de progreso (solo núcleo de Node) |
| `17-html-showcase-demo.html` | Página con gradientes, tarjetas animadas, CSS autocontenido |

Siguen mostrando al final una línea `*_SHOWCASE_DEMO_OK` (o como insignia, en el caso del HTML) para que sea fácil localizarlas en una captura o en una comprobación rápida.

## Ejemplos prácticos

Un tercer conjunto: herramientas pequeñas pero realmente útiles, una por lenguaje habitual, cada una con su propio icono. A diferencia de los dos conjuntos anteriores, el `ORDER` las coloca después del conjunto vistoso (`180`-`200`) en vez de después del número de su propio nombre de fichero, para que un ejemplo del "mundo real" nunca compita por el mismo puesto de menú con lo básico de su lenguaje.

| Fichero | Cobertura principal |
|---|---|
| `01-system-glance.sh` | Panel real: uptime, carga media, memoria y uso de disco |
| `02-password-generator.py` | Dos preguntas `ASK`, generación con `secrets`, estimación de entropía |
| `03-quick-notes.js` | E/S de fichero en ambos sentidos: añade una nota con fecha junto a sí mismo y lista las últimas |

`03-quick-notes.js` es la única excepción a "no escriben ficheros" de más abajo: guarda sus notas en `showcase-notes.txt`, junto al propio script. Puedes borrar ese fichero cuando quieras para reiniciarlo.

`showcase-gauge.svg`, `showcase-key.svg` y `showcase-notepad.svg` son sus iconos, uno por ejemplo, con el mismo estilo minimalista que `demo-blue.svg`/`demo-green.svg`.

## Verificación rápida

Configura `examples/scripts` como carpeta de scripts de Scriptya y comprueba primero la detección. Después usa:

- `01-shell-demo.sh` para el recorrido normal.
- `09-confirm-and-ask.sh` para confirmación y dos preguntas.
- `10-failure.sh` para errores e historial; debe devolver `7`.
- `08-html-demo.html` para detección HTML, edición de metadatos y apertura en navegador.
- `Cambiar icono` sobre una demo instalada para alternar entre `demo-blue.svg` y `demo-green.svg`.
- `Insertar metadatos` sobre una copia desechable; Enter conserva el valor y `-` lo vacía.
- `scriptya l` para probar la interfaz en inglés/español sin cambiar el código ni la salida de las demos.

Para ejecución directa, pasa un argumento como `demo` a los ejemplos de script. Los prefijos esperados son `SHELL_DEMO_OK`, `PYTHON_DEMO_OK`, `NODE_DEMO_OK`, `PERL_DEMO_OK`, `RUBY_DEMO_OK`, `LUA_DEMO_OK`, `FISH_DEMO_OK`, `PHP_DEMO_OK`, `AWK_DEMO_OK` y `GO_DEMO_OK`.

`09-confirm-and-ask.sh` debe mostrar los dos valores introducidos. `10-failure.sh` debe mostrar `EXPECTED_FAILURE|7` y terminar con `7`. La página HTML debe mostrar `HTML_DEMO_OK`.

Los ejemplos prácticos muestran `SYSTEM_GLANCE_OK`, `PASSWORD_DEMO_OK|<longitud>|<y o n>` y `QUICK_NOTES_OK|<número de notas>` respectivamente.

## Seguros por defecto

Los ejemplos no activan `SUDO` ni `TERMINAL`, no modifican el sistema, no usan servicios de red y no requieren privilegios elevados. Prueba esas opciones sobre una copia desechable cuando sea necesario. Lua, Fish, PHP CLI, AWK y Go requieren sus herramientas habituales; si falta un intérprete, Scriptya debe informarlo en vez de ocultarlo. Los ejemplos vistosos siguen las mismas reglas; el de Node.js solo usa las APIs propias del núcleo de Node (sin necesidad de `npm install`) y el de HTML no tiene etiqueta `<script>` ni carga ningún recurso remoto. El único fichero que se escribe en cualquiera de los conjuntos es el `showcase-notes.txt` propio de `03-quick-notes.js`, descrito arriba.

Los metadatos son deliberadamente cortos y solo cubren funciones que los ejemplos demuestran. Los nombres y rutas originales forman parte del contrato de la demo y no deben cambiarse.
