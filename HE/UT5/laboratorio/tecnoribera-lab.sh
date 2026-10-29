#!/usr/bin/env bash
# =============================================================================
# TECNORIBERA Lab — despliegue automatico (todo-en-uno) para Ubuntu/Debian/Kali
# Autor: Jose Picon
#
# Uso:
#   sudo bash tecnoribera-lab.sh             # instala y levanta el lab
#   sudo bash tecnoribera-lab.sh -y          # idem, sin preguntas (para SSH host)
#   bash tecnoribera-lab.sh --export         # (en un equipo CON internet) genera
#                                            # tecnoribera-images.tar para llevar
#                                            # en USB al Ubuntu del aula
#   sudo bash tecnoribera-lab.sh --stop      # para el lab
#   sudo bash tecnoribera-lab.sh --destroy   # borra contenedores y volumenes
#
# Modo sin internet / Docker Hub bloqueado:
#   Copia tecnoribera-lab.sh + tecnoribera-images.tar en la MISMA carpeta del
#   Ubuntu destino y lanza el script: carga las imagenes del .tar sin descargar.
#   (Docker tiene que estar ya instalado en ese Ubuntu.)
# =============================================================================
# Lo que hace, en orden:
#   1. Verifica root y que se ejecuta con bash (no sh/dash).
#   2. Comprueba e instala Docker Engine + Compose plugin si no estan.
#   3. Añade al usuario al grupo docker (sesiones nuevas).
#   4. En hosts ARM64 activa emulacion amd64 (DVWA y MySQL 5.7 solo son amd64).
#   5. Crea toda la estructura del laboratorio en ~/tecnoribera-vuln-lab/.
#   6. Libera el puerto 22 (ssh.socket/ssh.service) y comprueba el resto.
#   7. Carga imagenes desde tecnoribera-images.tar o las descarga (con
#      reintentos y espejo mirror.gcr.io si Docker Hub falla).
#   8. Levanta los 6 contenedores y espera a que respondan.
#   9. Smoke test e imprime la IP_PORTAL para la pizarra.
# =============================================================================

# ---- Si lo lanzan con "sh" (dash en Ubuntu), re-ejecutar con bash ----
if [ -z "${BASH_VERSION:-}" ]; then
    exec bash "$0" "$@"
fi

set -euo pipefail

# ---- Colores ----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

say()  { echo -e "${BLUE}[*]${NC} $*"; }
ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[ERR]${NC} $*" >&2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGES_TAR_NAME="tecnoribera-images.tar"

# Imagenes del lab (deben coincidir con docker-compose.yml)
IMAGES=(
    "nginx:1.14-alpine"
    "vulnerables/web-dvwa:latest"
    "bkimminich/juice-shop:v15.0.0"
    "mysql:5.7"
    "linuxserver/openssh-server:latest"
    "dperson/samba:latest"
)
# Solo existen para amd64: se fuerzan a amd64 (emulado en ARM64)
AMD64_ONLY=("vulnerables/web-dvwa:latest" "mysql:5.7")

is_amd64_only() {
    local i
    for i in "${AMD64_ONLY[@]}"; do [[ "$i" == "$1" ]] && return 0; done
    return 1
}

# Plataforma a usar para una imagen: amd64 forzado o la nativa del host
platform_for() {
    local target_arch="$2"
    if is_amd64_only "$1"; then echo "linux/amd64"; else echo "linux/$target_arch"; fi
}

host_docker_arch() {
    case "$(uname -m)" in
        x86_64|amd64)  echo amd64 ;;
        aarch64|arm64) echo arm64 ;;
        *)             uname -m ;;
    esac
}

# Descarga una imagen: Docker Hub con reintentos y, si falla, espejo de Google
pull_image() {
    local img="$1" plat="$2" n mirror
    for n in 1 2 3; do
        if docker pull --platform "$plat" "$img"; then return 0; fi
        warn "Fallo al descargar $img (intento $n/3)."
        sleep $((n * 5))
    done
    # mirror.gcr.io replica Docker Hub (ayuda con toomanyrequests / bloqueos)
    if [[ "$img" == */* ]]; then mirror="mirror.gcr.io/$img"; else mirror="mirror.gcr.io/library/$img"; fi
    warn "Probando espejo $mirror ..."
    if docker pull --platform "$plat" "$mirror"; then
        docker tag "$mirror" "$img"
        return 0
    fi
    return 1
}

usage() {
    sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
}

# ---- Argumentos ----
MODE="install"
ASSUME_YES=0
EXPORT_FILE="$SCRIPT_DIR/$IMAGES_TAR_NAME"
EXPORT_ARCH="amd64"
while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--yes)    ASSUME_YES=1 ;;
        --export)    MODE="export"
                     if [[ -n "${2:-}" && "${2:0:1}" != "-" ]]; then EXPORT_FILE="$2"; shift; fi ;;
        --arch)      EXPORT_ARCH="${2:?--arch necesita amd64 o arm64}"; shift ;;
        --stop)      MODE="stop" ;;
        --destroy)   MODE="destroy" ;;
        -h|--help)   usage; exit 0 ;;
        *)           err "Opcion desconocida: $1"; usage; exit 1 ;;
    esac
    shift
done

# =============================================================================
# MODO EXPORT: preparar el .tar de imagenes en un equipo con internet
# =============================================================================
if [[ "$MODE" == "export" ]]; then
    command -v docker &>/dev/null || { err "Necesitas Docker en este equipo para exportar."; exit 1; }
    say "Exportando imagenes para Ubuntu $EXPORT_ARCH -> $EXPORT_FILE"
    for img in "${IMAGES[@]}"; do
        plat=$(platform_for "$img" "$EXPORT_ARCH")
        say "Descargando $img ($plat)"
        pull_image "$img" "$plat" || { err "No se pudo descargar $img"; exit 1; }
    done
    # docker save guarda la variante descargada; si este equipo tiene otra
    # arquitectura que el destino, se pide la plataforma explicita (Docker >=27)
    SAVE_HELP=$(docker save --help 2>&1 || true)
    if [[ "$SAVE_HELP" == *--platform* && "$(host_docker_arch)" != "$EXPORT_ARCH" ]]; then
        say "Guardando imagenes (plataforma por imagen)..."
        tmpd=$(mktemp -d)
        i=0
        for img in "${IMAGES[@]}"; do
            plat=$(platform_for "$img" "$EXPORT_ARCH")
            docker save --platform "$plat" -o "$tmpd/$i.tar" "$img"
            i=$((i + 1))
        done
        # empaquetar los N tar en uno; el destino los carga uno a uno
        tar -C "$tmpd" -cf "$EXPORT_FILE" .
        rm -rf "$tmpd"
    else
        docker save -o "$EXPORT_FILE" "${IMAGES[@]}"
    fi
    ok "Listo: $EXPORT_FILE ($(du -h "$EXPORT_FILE" | cut -f1))"
    echo "  Copia al Ubuntu destino, en la misma carpeta:"
    echo "    $(basename "$0")  y  $(basename "$EXPORT_FILE")"
    echo "  y ejecuta alli: sudo bash $(basename "$0")"
    exit 0
fi

# ---- Comprobar root ----
if [[ $EUID -ne 0 ]]; then
    err "Este script debe ejecutarse como root (usa sudo)."
    echo "  sudo bash $0"
    exit 1
fi

# ---- Detectar usuario real (el que invoco sudo) ----
REAL_USER="${SUDO_USER:-root}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6 || true)
if [[ -z "$REAL_HOME" || ! -d "$REAL_HOME" ]]; then
    REAL_USER="root"
    REAL_HOME="/root"
fi
LAB="$REAL_HOME/tecnoribera-vuln-lab"

# ---- MODOS stop / destroy ----
if [[ "$MODE" == "stop" || "$MODE" == "destroy" ]]; then
    [[ -f "$LAB/docker-compose.yml" ]] || { err "No existe $LAB/docker-compose.yml"; exit 1; }
    cd "$LAB"
    if [[ "$MODE" == "stop" ]]; then
        docker compose stop
        ok "Lab parado."
    else
        docker compose down -v
        ok "Lab destruido (contenedores y volumenes)."
    fi
    say "Para recuperar el SSH del host: sudo systemctl start ssh.socket ssh"
    exit 0
fi

banner() {
cat <<'EOF'

 _____ _____ ____  _   _  ___  ____  ___ ____  _____ ____    _
|_   _| ____/ ___|| \ | |/ _ \|  _ \|_ _| __ )| ____|  _ \  / \
  | | |  _|| |    |  \| | | | | |_) || ||  _ \|  _| | |_) |/ _ \
  | | | |__| |___ | |\  | |_| |  _ < | || |_) | |___|  _ </ ___ \
  |_| |_____\____||_| \_|\___/|_| \_\___|____/|_____|_| \_\_/   \_\

                 LABORATORIO VULNERABLE — DESPLIEGUE AUTOMATICO
                       (uso docente — HE UT5 S2)

EOF
}

banner

say "Usuario destino: $REAL_USER"
say "Carpeta del lab: $LAB"
echo

# ---- Distro ----
. /etc/os-release
OS_ID="${ID:-debian}"
case "$OS_ID" in
    ubuntu|debian) ;;
    kali)          OS_ID="debian" ;;
    *)  # Linux Mint, Pop!_OS, Zorin... -> base ubuntu/debian
        if [[ "${ID_LIKE:-}" == *ubuntu* ]]; then OS_ID="ubuntu"; else OS_ID="debian"; fi ;;
esac
if [[ "$OS_ID" == "ubuntu" ]]; then
    CODENAME="${UBUNTU_CODENAME:-${VERSION_CODENAME:-noble}}"
else
    CODENAME="${VERSION_CODENAME:-bookworm}"
    [[ "${ID:-}" == "kali" ]] && CODENAME="bookworm"
fi
say "Distro: ${PRETTY_NAME:-$OS_ID} (repo Docker: $OS_ID $CODENAME)"

add_docker_repo() {
    [[ -f /etc/apt/sources.list.d/docker.list ]] && return 0
    apt-get update
    apt-get install -y ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL "https://download.docker.com/linux/$OS_ID/gpg" | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS_ID $CODENAME stable" > /etc/apt/sources.list.d/docker.list
    apt-get update
}

# ---- Instalar Docker si falta ----
if ! command -v docker &>/dev/null; then
    warn "Docker no encontrado. Instalando desde el repositorio oficial..."
    # paquetes de Ubuntu que chocan con docker-ce
    for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
        apt-get remove -y "$pkg" &>/dev/null || true
    done
    add_docker_repo
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    ok "Docker instalado."
else
    ok "Docker ya estaba instalado: $(docker --version)"
fi

# ---- Daemon arrancado ----
if ! docker info &>/dev/null; then
    say "Arrancando el servicio docker..."
    systemctl enable --now docker 2>/dev/null || systemctl start docker 2>/dev/null || snap start docker 2>/dev/null || true
    for _ in $(seq 1 15); do docker info &>/dev/null && break; sleep 1; done
    docker info &>/dev/null || { err "El daemon de Docker no arranca. Mira: journalctl -u docker -n 50"; exit 1; }
fi
ok "Daemon Docker activo."

# ---- Compose plugin ----
if ! docker compose version &>/dev/null; then
    warn "Docker Compose plugin no encontrado. Instalando..."
    apt-get install -y docker-compose-plugin 2>/dev/null \
        || apt-get install -y docker-compose-v2 2>/dev/null \
        || { add_docker_repo && apt-get install -y docker-compose-plugin; }
fi
docker compose version &>/dev/null || { err "No hay 'docker compose' disponible."; exit 1; }
ok "Docker Compose: $(docker compose version 2>/dev/null | head -1)"

# ---- Emulacion amd64 en hosts ARM64 (Ubuntu/Kali ARM en Mac Apple Silicon) ----
# mysql:5.7 y vulnerables/web-dvwa solo existen para amd64: sin qemu fallan
# con "no matching manifest for linux/arm64/v8" o "exec format error".
HOST_ARCH=$(host_docker_arch)
if [[ "$HOST_ARCH" == "arm64" ]]; then
    warn "Host arm64: DVWA y MySQL 5.7 solo existen para amd64 -> se emulan con qemu."
    if [[ ! -e /proc/sys/fs/binfmt_misc/qemu-x86_64 ]]; then
        say "Instalando qemu-user-static + binfmt-support..."
        apt-get install -y qemu-user-static binfmt-support || true
        systemctl restart systemd-binfmt 2>/dev/null || true
    fi
    if [[ ! -e /proc/sys/fs/binfmt_misc/qemu-x86_64 ]]; then
        say "Registrando binfmt amd64 via tonistiigi/binfmt..."
        docker run --privileged --rm tonistiigi/binfmt --install amd64 || true
    fi
    if [[ -e /proc/sys/fs/binfmt_misc/qemu-x86_64 ]]; then
        ok "Emulacion amd64 activa."
    else
        err "No se pudo activar la emulacion amd64; DVWA y MySQL no arrancaran."
        exit 1
    fi
fi

# ---- Grupo docker ----
if [[ "$REAL_USER" != "root" ]] && ! id -nG "$REAL_USER" | grep -qw docker; then
    usermod -aG docker "$REAL_USER"
    warn "Añadido $REAL_USER al grupo docker (necesitara nueva sesion para usarlo sin sudo)."
fi

# ---- Utilidades necesarias ----
for cmd in python3 curl ss; do
    if ! command -v "$cmd" &>/dev/null; then
        case "$cmd" in
            ss) apt-get install -y iproute2 ;;
            *)  apt-get install -y "$cmd" ;;
        esac
    fi
done

echo
say "Creando estructura del laboratorio en $LAB ..."
mkdir -p "$LAB/portal/html/.git" "$LAB/portal/conf.d" "$LAB/samba/share"

# ---- docker-compose.yml ----
cat > "$LAB/docker-compose.yml" <<'YAML'
services:
  portal:
    image: nginx:1.14-alpine
    container_name: tecnoribera-portal
    ports: ["80:80"]
    volumes:
      - ./portal/html:/usr/share/nginx/html:ro
      - ./portal/conf.d:/etc/nginx/conf.d:ro
    restart: unless-stopped

  dvwa:
    image: vulnerables/web-dvwa:latest
    platform: linux/amd64
    container_name: tecnoribera-dvwa
    ports: ["8080:80"]
    restart: unless-stopped

  juiceshop:
    image: bkimminich/juice-shop:v15.0.0
    container_name: tecnoribera-juice
    ports: ["3000:3000"]
    restart: unless-stopped

  mysql:
    image: mysql:5.7
    platform: linux/amd64
    container_name: tecnoribera-mysql
    ports: ["3306:3306"]
    environment:
      MYSQL_ROOT_PASSWORD: toor1234
      MYSQL_DATABASE: tecnoribera
      MYSQL_USER: tecno
      MYSQL_PASSWORD: tecno1234
    restart: unless-stopped

  ssh-lab:
    image: linuxserver/openssh-server:latest
    container_name: tecnoribera-ssh
    ports: ["22:2222"]
    environment:
      PUID: "1000"
      PGID: "1000"
      TZ: Europe/Madrid
      PASSWORD_ACCESS: "true"
      USER_NAME: tecnoribera
      USER_PASSWORD: admin1234
      SUDO_ACCESS: "false"
    restart: unless-stopped

  samba:
    image: dperson/samba:latest
    container_name: tecnoribera-samba
    ports:
      - "139:139"
      - "445:445"
    command: '-u "tecno;tecno1234" -s "publico;/share;yes;no;yes;all;none;none" -w WORKGROUP -g "map to guest = Bad User"'
    volumes:
      - ./samba/share:/share
    restart: unless-stopped
YAML

# ---- nginx conf ----
cat > "$LAB/portal/conf.d/default.conf" <<'NGINX'
server {
    listen 80 default_server;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;
    server_tokens on;

    location = /admin    { return 403; }
    location = /admin/   { return 403; }
    location = /internal { return 403; }

    location = /login {
        try_files /login.html =404;
    }

    location ~ /\.env$ {
        default_type text/plain;
    }
    location /.git/ {
        autoindex off;
    }

    location / {
        try_files $uri $uri/ =404;
    }
}
NGINX

# ---- index.html ----
cat > "$LAB/portal/html/index.html" <<'HTML'
<!DOCTYPE html>
<html lang="es">
<head><meta charset="utf-8"><title>Portal Tecnoribera</title>
<style>body{font-family:Arial;max-width:720px;margin:40px auto;padding:0 20px}h1{color:#003366}</style></head>
<body>
<h1>Portal Corporativo — TECNORIBERA, S.L.</h1>
<p>Bienvenido al portal corporativo. Acceso solo para empleados autorizados.</p>
<p>Si eres cliente, llama al 963 00 00 00.</p>
<p><a href="/login">Acceder al panel de empleados</a></p>
<hr><small>&copy; 2026 TECNORIBERA, S.L. — Valencia</small>
</body></html>
HTML

# ---- login.html ----
cat > "$LAB/portal/html/login.html" <<'HTML'
<!DOCTYPE html>
<html lang="es"><head><meta charset="utf-8"><title>Login - Tecnoribera</title></head>
<body>
<h2>Acceso de empleados</h2>
<form method="post" action="/login">
  <label>Usuario: <input name="user"></label><br><br>
  <label>Password: <input type="password" name="pass"></label><br><br>
  <button>Entrar</button>
</form>
<p><small>Si has olvidado tu clave, contacta a sistemas@tecnoribera.local</small></p>
</body></html>
HTML

# ---- robots.txt ----
cat > "$LAB/portal/html/robots.txt" <<'TXT'
User-agent: *
Disallow: /admin
Disallow: /backup.zip
Disallow: /.git
Disallow: /phpinfo.php
Disallow: /internal
TXT

# ---- phpinfo.php (como estatico) ----
cat > "$LAB/portal/html/phpinfo.php" <<'PHP'
<html><body><h1>PHP Version 7.4.3</h1>
<pre>
System: Linux portal 5.15.0-78-generic #85 x86_64 GNU/Linux
Build Date: Apr 10 2026
Server API: Apache 2.4 Handler
Loaded Configuration File: /etc/php/7.4/apache2/php.ini
SMTP: smtp.tecnoribera.local
sendmail_from: notificaciones@tecnoribera.local
PHP_ADMIN_EMAIL: it@tecnoribera.local
disable_functions: (none)
display_errors: On
expose_php: On
</pre>
</body></html>
PHP

# ---- .env ----
cat > "$LAB/portal/html/.env" <<'ENV'
APP_NAME=TecnoriberaPortal
APP_ENV=production
APP_DEBUG=true
APP_KEY=base64:dGVjbm9yaWJlcmFsYWJvcmF0b3JpbzIwMjYxMDIy
APP_URL=http://portal.tecnoribera.local

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=tecnoribera
DB_USERNAME=tecno
DB_PASSWORD=tecno1234

MAIL_HOST=smtp.tecnoribera.local
MAIL_USERNAME=notificaciones
MAIL_PASSWORD=sYz72Qp!TR
MAIL_PORT=587

ADMIN_API_KEY=sk_live_EXAMPLE_tecnoribera_lab_no_real_0000
ENV

# ---- .git ----
cat > "$LAB/portal/html/.git/HEAD" <<'EOF'
ref: refs/heads/main
EOF

cat > "$LAB/portal/html/.git/config" <<'EOF'
[core]
    repositoryformatversion = 0
    filemode = true
    bare = false
    logallrefupdates = true
[remote "origin"]
    url = git@gitlab.internal.tecnoribera.local:web/portal.git
    fetch = +refs/heads/*:refs/remotes/origin/*
[user]
    name = oscar.valcarcel
    email = oscar.valcarcel@tecnoribera.local
EOF

# ---- backup.zip (con python) ----
python3 - "$LAB/portal/html/backup.zip" <<'PY'
import sys, zipfile
path = sys.argv[1]
with zipfile.ZipFile(path, "w") as z:
    z.writestr("README.txt", "Backup del portal 2026-07-15. NO SUBIR A GIT.\n")
    z.writestr("db-backup.sql.enc", "ENCRYPTED PLACEHOLDER\n" * 50)
    z.writestr("credenciales.txt",
               "admin:TecnoRibera2024!\n"
               "oscar.valcarcel:P@ssw0rd2024\n"
               "rrhh:rrhh1234\n")
print("backup.zip generado en:", path)
PY

# ---- samba share chismoso ----
cat > "$LAB/samba/share/README.txt" <<'TXT'
Share "publico" — TECNORIBERA, S.L.
Esta carpeta es accesible por los proveedores externos.
Para subir facturas, use el subdirectorio /facturas.
En caso de duda, contactar con oscar.valcarcel@tecnoribera.local
TXT

cat > "$LAB/samba/share/credenciales-vpn-OLD.txt" <<'TXT'
NO USAR — credenciales antiguas de la VPN (2024).
Usuario: tecno-vpn
Password: Vpn2024Tecno!
Rotadas por SI el 15-07-2026.
TXT

# ---- permisos ----
if [[ "$REAL_USER" != "root" ]]; then
    chown -R "$REAL_USER:$REAL_USER" "$LAB"
fi
ok "Ficheros del lab generados."

# ---- liberar puerto 22 si el SSH del host lo ocupa ----
# Ubuntu 22.10+ usa ssh.socket: el 22 aparece como "systemd", no "sshd".
port_busy() { [[ -n "$(ss -Htln "sport = :$1" 2>/dev/null)" ]]; }
lab_running() { [[ "$(docker ps --format '{{.Names}}' 2>/dev/null)" == *tecnoribera-* ]]; }

echo
if ! lab_running; then
    if port_busy 22; then
        warn "El puerto 22 lo ocupa el SSH del host (ssh.service / ssh.socket)."
        echo "   Opciones:"
        echo "     A) Parar el SSH del host mientras dura la clase."
        echo "     B) Cancelar y editar $LAB/docker-compose.yml cambiando '22:2222' por '2222:2222'."
        echo
        ans="n"
        if [[ $ASSUME_YES -eq 1 ]]; then ans="s"; else read -r -p "¿Paro el SSH del host ahora para liberar el 22? [s/N] " ans || true; fi
        if [[ "$ans" =~ ^[sSyY]$ ]]; then
            systemctl stop ssh.socket ssh.service sshd.service 2>/dev/null || true
            sleep 1
            if port_busy 22; then
                err "El 22 sigue ocupado:"; ss -tlnp "sport = :22"; exit 1
            fi
            ok "SSH del host parado (vuelve con: sudo systemctl start ssh.socket ssh)."
        else
            warn "El SSH del host SIGUE corriendo. Abortando levantamiento automatico."
            exit 1
        fi
    fi

    # ---- resto de puertos: apache2/nginx/mysql/smbd del host suelen ocuparlos ----
    BUSY=0
    for p in 80 139 445 3000 3306 8080; do
        if port_busy "$p"; then
            err "Puerto $p ocupado en el host:"; ss -tlnp "sport = :$p"
            BUSY=1
        fi
    done
    if [[ $BUSY -eq 1 ]]; then
        err "Libera esos puertos y relanza, p.ej.:"
        echo "    sudo systemctl stop apache2 nginx mysql mariadb smbd nmbd"
        exit 1
    fi
fi

# ---- imagenes: desde .tar (offline) o descarga ----
echo
cd "$LAB"
TAR="$SCRIPT_DIR/$IMAGES_TAR_NAME"
if [[ -f "$TAR" ]]; then
    say "Cargando imagenes desde $TAR (modo sin internet)..."
    TAR_LIST=$(tar -tf "$TAR" 2>/dev/null || true)
    if [[ $'\n'"$TAR_LIST"$'\n' == *$'\n'0.tar$'\n'* || $'\n'"$TAR_LIST"$'\n' == *$'\n'./0.tar$'\n'* ]]; then
        # formato multi-plataforma generado por --export desde otra arquitectura
        tmpd=$(mktemp -d)
        tar -C "$tmpd" -xf "$TAR"
        for f in "$tmpd"/*.tar; do docker load -i "$f"; done
        rm -rf "$tmpd"
    else
        docker load -i "$TAR"
    fi
    ok "Imagenes cargadas."
fi

say "Comprobando imagenes (la primera descarga tarda 2-5 min)..."
FAILED=()
for img in "${IMAGES[@]}"; do
    plat=$(platform_for "$img" "$HOST_ARCH")
    if docker image inspect "$img" &>/dev/null; then
        ok "Ya presente: $img"
        continue
    fi
    say "Descargando $img ($plat)"
    pull_image "$img" "$plat" || FAILED+=("$img")
done
if [[ ${#FAILED[@]} -gt 0 ]]; then
    err "No se pudieron obtener: ${FAILED[*]}"
    echo "  Causas tipicas:"
    echo "   - 'toomanyrequests': limite de Docker Hub por IP -> 'docker login' y relanza."
    echo "   - timeout / DNS: el cortafuegos bloquea Docker Hub. Prueba:"
    echo "       curl -I https://registry-1.docker.io/v2/"
    echo "   - Sin internet: en un equipo con internet ejecuta"
    echo "       bash $(basename "$0") --export"
    echo "     y copia $IMAGES_TAR_NAME junto a este script."
    exit 1
fi

say "Levantando los 6 contenedores..."
docker compose up -d --pull never

# ---- esperar a que respondan (MySQL emulado tarda mas) ----
say "Esperando a que arranquen los servicios (max 180s)..."
ready=0
for i in $(seq 1 36); do
    c80=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 http://127.0.0.1/ || true)
    c8080=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 http://127.0.0.1:8080/ || true)
    c3000=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 http://127.0.0.1:3000/ || true)
    mysql_ok=0
    docker exec tecnoribera-mysql mysqladmin ping -uroot -ptoor1234 --silent &>/dev/null && mysql_ok=1
    if [[ "$c80" == "200" && "$c8080" =~ ^(200|302)$ && "$c3000" == "200" && $mysql_ok -eq 1 ]]; then
        ready=1; break
    fi
    sleep 5
done
[[ $ready -eq 1 ]] && ok "Servicios arriba." || warn "Algun servicio aun no responde; revisa el smoke test y 'docker compose logs'."

echo
say "Estado actual de los contenedores:"
docker compose ps

# ---- IP del host para la pizarra ----
# Robusta: descarta SIEMPRE loopback (127.*), link-local/APIPA (169.254.*) y las
# interfaces de Docker (docker0, br-*, veth*). Prioriza la interfaz FISICA real
# (en*/eth*/wl*), que es la que esta en la misma subred que los alumnos.
# Ojo: en el hotspot la IP la da el DHCP y CAMBIA cada sesion -> mira la de HOY.
pick_lab_ip() {
    local ip
    # 1) IP de la ruta por defecto (con la que el host sale a la red), si es real
    ip=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<NF;i++) if($i=="src"){print $(i+1); exit}}')
    if [[ -n "$ip" && "$ip" != 169.254.* && "$ip" != 127.* ]]; then
        echo "$ip"; return 0
    fi
    # 2) primera IPv4 de una interfaz fisica UP (no docker/bridge/veth/lo), no APIPA
    ip=$(ip -br -4 a 2>/dev/null | awk '
        $1 ~ /^(en|eth|wl|ens|enp|eno|wlp)/ && $2 == "UP" {
            for (i=3; i<=NF; i++) if ($i ~ /^[0-9]+\./) {
                split($i, a, "/"); addr=a[1]
                if (addr !~ /^169\.254\./ && addr !~ /^127\./) { print addr; exit }
            }
        }')
    [[ -n "$ip" ]] && { echo "$ip"; return 0; }
    return 1
}
IP_HOST=$(pick_lab_ip || true)
IP_OK=1
if [[ -z "$IP_HOST" ]]; then
    IP_OK=0
    IP_HOST="127.0.0.1"
    warn "No se ha detectado una IP de red valida (solo loopback/Docker/APIPA)."
    warn "El equipo del lab NO tiene IP del aula: revisa el cable/wifi y el DHCP."
fi

# ---- smoke test ----
echo
say "Smoke test contra $IP_HOST:"
echo
for test in \
    "portal 80|http://$IP_HOST/" \
    "dvwa 8080|http://$IP_HOST:8080/" \
    "juice 3000|http://$IP_HOST:3000/" \
    "/.env|http://$IP_HOST/.env" \
    "/.git/HEAD|http://$IP_HOST/.git/HEAD" \
    "/backup.zip|http://$IP_HOST/backup.zip" \
    "/robots.txt|http://$IP_HOST/robots.txt" ; do
    name="${test%%|*}"
    url="${test##*|}"
    code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null || true)
    printf "  %-14s -> %s\n" "$name" "${code:-FAIL}"
done
for p in 22 139 445 3306; do
    if timeout 3 bash -c "</dev/tcp/$IP_HOST/$p" 2>/dev/null; then
        printf "  %-14s -> abierto\n" "tcp $p"
    else
        printf "  %-14s -> CERRADO\n" "tcp $p"
    fi
done

echo
echo "========================================================================"
echo -e "${GREEN}${BOLD}  LABORATORIO TECNORIBERA LISTO${NC}"
echo "========================================================================"
echo
if [[ "$IP_OK" == "1" ]]; then
    echo -e "${BOLD}  IP del objetivo TECNORIBERA para la pizarra (${YELLOW}$(date '+%d/%m/%Y %H:%M')${NC}${BOLD}):${NC}"
    echo
    echo -e "    ##################################################"
    echo -e "    ##                                              ##"
    echo -e "    ##     ${YELLOW}${BOLD}>>>  $IP_HOST  <<<${NC}"
    echo -e "    ##                                              ##"
    echo -e "    ##################################################"
    echo
    echo -e "  ${BOLD}Comandos para los alumnos${NC} (mismo hotspot, su IP sera 172.20.10.x):"
    echo -e "      ${BOLD}curl http://$IP_HOST/${NC}"
    echo -e "      ${BOLD}nmap -sV -p- $IP_HOST${NC}"
    echo
    warn "Esta IP la asigna el DHCP y CAMBIA cada sesion. Usa la de HOY, no la de la clase anterior."
    warn "Para verla sin relanzar:  ip -br -4 a"
else
    echo -e "${RED}${BOLD}  SIN IP DE RED VALIDA — no escribas ninguna IP en la pizarra.${NC}"
    echo -e "  Diagnostico rapido:"
    echo -e "      ip -br -4 a                 # ¿hay una 172.x/192.168.x/10.x en una iface fisica?"
    echo -e "      sudo dhclient -v <iface>    # forzar peticion DHCP (o: sudo netplan apply)"
    echo -e "  Si solo salen 169.254.* o las de Docker, el DHCP no esta dando IP a este equipo."
fi
echo
echo "  Puertos expuestos:"
echo "    22   SSH    (OpenSSH; usuario 'tecnoribera' / 'admin1234')"
echo "    80   HTTP   (portal nginx 1.14 con hallazgos sembrados)"
echo "    139  SMB    (Samba, share 'publico' anonima)"
echo "    445  SMB"
echo "    3000 HTTP   (OWASP Juice Shop)"
echo "    3306 MySQL  (MySQL 5.7, root/toor1234)"
echo "    8080 HTTP   (DVWA)"
echo
echo "  Comandos utiles mientras dura la clase:"
echo "    cd $LAB"
echo "    docker compose ps                    # ver estado"
echo "    docker compose logs -f portal        # ver logs en vivo"
echo "    docker compose restart portal"
echo
echo "  Para parar al terminar la clase:"
echo "    sudo bash $SCRIPT_DIR/$(basename "$0") --stop"
echo "    sudo systemctl start ssh.socket ssh  # devolver el SSH al host"
echo
echo "  Para destruir todo (datos incluidos):"
echo "    sudo bash $SCRIPT_DIR/$(basename "$0") --destroy"
echo
echo "========================================================================"
echo
