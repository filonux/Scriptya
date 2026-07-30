# Contribuir

Gracias por el interés. Esto es lo básico:

## Reportar un error o proponer una mejora

Abre un issue — hay una plantilla para cada caso.

## Enviar un cambio

1. Haz un fork y crea una rama a partir de la última versión.
2. Prueba el cambio: al menos `bash -n script/scriptya.sh` sin errores; si tienes `shellcheck` instalado, pásalo también. Si puedes probarlo en Linux Mint/Cinnamon (el entorno donde se desarrolla), mejor.
3. Abre el pull request — la plantilla te guía sobre qué contar.

## Estilo del código

- Bash con `set -uo pipefail`, comillas dobles en las expansiones, `--` antes de rutas que puedan empezar por `-`.
- Comentarios solo donde aclaran un porqué no obvio, no para repetir lo que ya dice el código.
- Si el cambio toca iconos, ficheros `.desktop` o rutas de escritorio: se prueba principalmente en Cinnamon, así que indica en el PR si podría afectar a otros entornos.
