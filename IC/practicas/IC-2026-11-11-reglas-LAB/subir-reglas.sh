#!/bin/sh
# Copia local_decoder.xml y local_rules.xml a TU manager de Wazuh y comprueba que se cargan.
# Uso, desde la carpeta del laboratorio:
#   ./subir-reglas.sh                      (Wazuh con docker compose en ~/wazuh-docker/single-node)
#   WAZUH_DIR=/otra/ruta ./subir-reglas.sh (si tu docker compose está en otra carpeta)
#   CONTENEDOR=ic-logtest ./subir-reglas.sh (si usas un manager suelto, plan B)
set -eu
LAB=$(cd "$(dirname "$0")" && pwd)
WAZUH_DIR=${WAZUH_DIR:-$HOME/wazuh-docker/single-node}
DEC=/var/ossec/etc/decoders/local_decoder.xml
REG=/var/ossec/etc/rules/local_rules.xml

if [ -n "${CONTENEDOR:-}" ]; then
    copiar() { docker cp "$1" "$CONTENEDOR:$2"; }
    ejecutar() { docker exec "$CONTENEDOR" "$@"; }
else
    cd "$WAZUH_DIR"
    copiar() { docker compose cp "$1" "wazuh.manager:$2"; }
    ejecutar() { docker compose exec -T wazuh.manager "$@"; }
fi

# La primera vez guarda una copia de cada fichero original del manager.
# Se escribe en un temporal y solo se renombra si la copia ha salido bien.
for par in "$REG:ORIGINAL-local_rules.xml" "$DEC:ORIGINAL-local_decoder.xml"; do
    origen=${par%%:*}
    copia=$LAB/${par#*:}
    if [ ! -s "$copia" ]; then
        ejecutar cat "$origen" > "$copia.tmp"
        mv "$copia.tmp" "$copia"
        echo "Copia del original guardada en $copia"
    fi
done

copiar "$LAB/local_decoder.xml" "$DEC"
copiar "$LAB/local_rules.xml" "$REG"
ejecutar chown wazuh:wazuh "$DEC" "$REG"

if ejecutar /var/ossec/bin/wazuh-analysisd -t; then
    echo "OK: el manager acepta tus reglas. Ya puedes probarlas con wazuh-logtest."
else
    echo "ERROR: el manager no acepta tus ficheros. Lee el mensaje de arriba (fichero y línea)."
    echo "Los ficheros con error ya están dentro del manager: NO lo reinicies hasta corregirlos."
    exit 1
fi
