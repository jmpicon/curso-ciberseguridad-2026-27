#!/bin/sh
# Simula en TU equipo unos eventos del portal de nóminas (aplicación ficticia).
# Solo escribe mensajes en el registro del sistema con logger: no se conecta a nada.
# 203.0.113.77 pertenece a un rango reservado para documentación.
set -eu
IP_EXTERNA=203.0.113.77
# Si subes mucho la pausa, los seis fallos no caerán dentro de los 120 s de la regla 100110.
PAUSA=${PAUSA:-3}

evento() {
    logger -t portal-nominas "$*"
    echo "$(date '+%H:%M:%S') $*"
    sleep "$PAUSA"
}

evento login_ok user=marcos src=10.20.0.44
for i in 1 2 3 4 5 6; do
    evento login_fail user=admin src=$IP_EXTERNA
done
evento login_ok user=lucia src=$IP_EXTERNA
evento export user=lucia src=$IP_EXTERNA registros=4812
echo "Hecho. Espera un minuto y busca las alertas en tu Wazuh."
