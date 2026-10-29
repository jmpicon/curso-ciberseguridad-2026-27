#!/usr/bin/env bash
#
# labnet-up.sh — Orquesta el laboratorio de VMs del curso sobre VirtualBox.
#
# Complementa a los objetivos Docker (objetivos/docker-compose.yml): cuando el
# objetivo es una VM completa y vulnerable (Metasploitable, o una víctima de SO),
# este script la cablea a la red aislada del lab y garantiza que NO toca la red
# del centro ni Internet durante el ejercicio.
#
# Red del lab: Internal Network "labnet" (10.10.10.0/24), la misma convención
# que el resto del escenario xest. Sin DHCP propio: asigna IP estática en cada
# guest (ver LABORATORIO-VM.md) o levanta un pfSense como gateway.
#
# REGLA DE ORO del curso: nada del lab se ejecuta contra la red del centro ni
# contra Internet. El gate de este script PROHÍBE la NIC en modo 'bridged'
# (la única que pone la VM en tu red física real). El acceso a Internet, cuando
# haga falta para descargar/actualizar herramientas, se da por NAT y SOLO en la
# máquina atacante o de forma temporal; en el ejercicio se desconecta (wan-off).
#
# Uso:
#   ./labnet-up.sh check          # audita red de todas las VMs del lab (NO arranca)
#   ./labnet-up.sh wire           # fuerza la NIC1 de lab a intnet "labnet" (idempotente)
#   ./labnet-up.sh wan-on  <vm>   # da Internet a <vm> (NIC2 NAT, cable conectado)
#   ./labnet-up.sh wan-off <vm>   # corta Internet de <vm> (desconecta la NIC2)
#   ./labnet-up.sh snapshot       # snapshot base 'base-clean' por VM si no existe
#   ./labnet-up.sh up             # check + arranca todas (headless)
#   ./labnet-up.sh down           # apaga todas (ACPI, luego poweroff)
#   ./labnet-up.sh restore        # restaura cada VM a 'base-clean'
#   ./labnet-up.sh status         # estado y NICs activas de cada VM
#
set -euo pipefail

# ─── Configuración ──────────────────────────────────────────────────────────
LABNET="labnet"            # nombre de la Internal Network del lab
SUBNET="10.10.10"          # /24 del laboratorio (convención xest)
SNAP_BASE="base-clean"     # nombre del snapshot limpio por VM

# VMs del laboratorio.  Formato:  "NombreVM:ROL"
#   ROL=lab  -> atacante / víctima / monitor. Nunca 'bridged'.
#   ROL=fw   -> firewall/gateway pfSense: se le permite UNA NIC de salida (WAN).
# IMPORTANTE: pon los nombres EXACTOS de tus VMs (VBoxManage list vms).
LAB_VMS=(
  "kali:lab"               # atacante (ajusta el nombre al de tu VM Kali)
  "metasploitable:lab"     # víctima vulnerable
  # "pfSense:fw"           # gateway con egreso filtrado (opcional)
  # "wazuh:lab"            # monitor / SIEM del lab
)

# ─── Utilidades ─────────────────────────────────────────────────────────────
c_red()  { printf '\033[31m%s\033[0m\n' "$*"; }
c_grn()  { printf '\033[32m%s\033[0m\n' "$*"; }
c_ylw()  { printf '\033[33m%s\033[0m\n' "$*"; }
die()    { c_red "ERROR: $*" >&2; exit 1; }

command -v VBoxManage >/dev/null 2>&1 || die "VBoxManage no está en el PATH. Instala VirtualBox."

vm_exists()  { VBoxManage list vms | grep -q "\"$1\""; }
vm_running() { VBoxManage list runningvms | grep -q "\"$1\""; }

# NICs ACTIVAS de una VM (descarta las 60+ ranuras none/null vacías).
vm_nics() {
  local out
  out="$(VBoxManage showvminfo "$1" --machinereadable 2>/dev/null \
    | grep -E '^nic[0-9]+=' | tr -d '"' \
    | grep -Ev '=(none|null)$' | tr '\n' ' ')"
  echo "${out:-<sin NIC activa>}"
}

# Busca el nombre real de una VM del array a partir de un alias dado por el usuario.
resolve_vm() {
  local q="$1"
  for entry in "${LAB_VMS[@]}"; do
    [[ "${entry%%:*}" == "$q" ]] && { echo "$q"; return 0; }
  done
  echo "$q"   # no está en el array: se usa tal cual (debe existir en VBox)
}

# ─── Gate de fuga de red ──────────────────────────────────────────────────────
# Lo ÚNICO prohibido es 'bridged' (pone la VM en tu LAN física real).
# Se permiten: intnet (lab), nat/natnetwork (salida a Internet consciente),
# hostonly y vacía. NAT no expone tu red: solo da salida saliente.
check_vm() {
  local vm="$1" rol="$2"
  local nics; nics="$(vm_nics "$vm")"
  local bridged=0 wan=0

  for pair in $nics; do
    local val="${pair#*=}"
    case "$val" in
      bridged)
        bridged=$((bridged+1))
        c_red "  FUGA: $vm tiene una NIC 'bridged' (expone tu LAN real — PROHIBIDO)"
        ;;
      nat|natnetwork) wan=$((wan+1)) ;;
      intnet|hostonly|none|null|"") : ;;
      *) c_ylw "  aviso: $vm NIC desconocida '$val'";;
    esac
  done

  if [[ "$bridged" -gt 0 ]]; then
    return 1
  fi
  if [[ "$rol" == "lab" && "$wan" -gt 0 ]]; then
    c_ylw "  OK (con aviso): $vm tiene salida a Internet (NAT). Usa 'wan-off $vm' durante el ejercicio."
  else
    c_grn "  OK: $vm ($rol) — sin fuga a LAN real"
  fi
  return 0
}

cmd_check() {
  local fail=0
  echo "Auditando aislamiento de red (Internal Network '$LABNET', $SUBNET.0/24)…"
  for entry in "${LAB_VMS[@]}"; do
    local vm="${entry%%:*}" rol="${entry##*:}"
    vm_exists "$vm" || { c_ylw "  (omitida) VM '$vm' no existe aún"; continue; }
    check_vm "$vm" "$rol" || fail=1
  done
  if [[ "$fail" -ne 0 ]]; then
    die "Gate de aislamiento FALLÓ (hay una NIC 'bridged'). Corrígela antes de arrancar."
  fi
  c_grn "Gate de aislamiento superado."
}

# ─── Cableado ─────────────────────────────────────────────────────────────────
cmd_wire() {
  for entry in "${LAB_VMS[@]}"; do
    local vm="${entry%%:*}" rol="${entry##*:}"
    vm_exists "$vm" || { c_ylw "(omitida) '$vm' no existe"; continue; }
    vm_running "$vm" && { c_ylw "(omitida) '$vm' en ejecución; apágala para re-cablear"; continue; }
    if [[ "$rol" == "lab" ]]; then
      VBoxManage modifyvm "$vm" --nic1 intnet --intnet1 "$LABNET" --cableconnected1 on
      c_grn "cableada $vm -> intnet '$LABNET'"
    else
      c_ylw "firewall ('$vm'): configura LAN=intnet '$LABNET' y WAN=nat a mano (no se toca)"
    fi
  done
}

# ─── Internet (WAN) bajo control ───────────────────────────────────────────────
cmd_wan_on() {
  local vm; vm="$(resolve_vm "${1:?uso: wan-on <vm>}")"
  vm_exists "$vm" || die "la VM '$vm' no existe"
  if vm_running "$vm"; then
    VBoxManage modifyvm "$vm" --nic2 nat 2>/dev/null || true
    VBoxManage controlvm "$vm" setlinkstate2 on
  else
    VBoxManage modifyvm "$vm" --nic2 nat --cableconnected2 on
  fi
  c_grn "Internet ACTIVADO en $vm (NIC2 NAT). Recuerda 'wan-off $vm' antes del ejercicio ofensivo."
}

cmd_wan_off() {
  local vm; vm="$(resolve_vm "${1:?uso: wan-off <vm>}")"
  vm_exists "$vm" || die "la VM '$vm' no existe"
  if vm_running "$vm"; then
    VBoxManage controlvm "$vm" setlinkstate2 off 2>/dev/null || true
  else
    VBoxManage modifyvm "$vm" --cableconnected2 off 2>/dev/null || true
  fi
  c_grn "Internet DESCONECTADO en $vm. La VM queda solo en la red aislada del lab."
}

# ─── Snapshots ────────────────────────────────────────────────────────────────
cmd_snapshot() {
  for entry in "${LAB_VMS[@]}"; do
    local vm="${entry%%:*}"
    vm_exists "$vm" || continue
    if VBoxManage snapshot "$vm" list --machinereadable 2>/dev/null | grep -q "SnapshotName.*=\"$SNAP_BASE\""; then
      c_ylw "snapshot '$SNAP_BASE' ya existe en $vm"
    else
      VBoxManage snapshot "$vm" take "$SNAP_BASE" --description "estado limpio pre-ataque $(date -u +%FT%TZ)"
      c_grn "snapshot '$SNAP_BASE' tomado en $vm"
    fi
  done
}

# ─── Arranque / parada / restauración ──────────────────────────────────────────
cmd_up() {
  cmd_check
  for entry in "${LAB_VMS[@]}"; do
    local vm="${entry%%:*}"
    vm_exists "$vm" || { c_ylw "(omitida) '$vm' no existe"; continue; }
    if vm_running "$vm"; then c_ylw "$vm ya en ejecución"
    else VBoxManage startvm "$vm" --type headless && c_grn "arrancada $vm (headless)"; fi
  done
}

cmd_down() {
  for entry in "${LAB_VMS[@]}"; do
    local vm="${entry%%:*}"; vm_running "$vm" || continue
    VBoxManage controlvm "$vm" acpipowerbutton 2>/dev/null || true
  done
  sleep 8
  for entry in "${LAB_VMS[@]}"; do
    local vm="${entry%%:*}"; vm_running "$vm" || continue
    VBoxManage controlvm "$vm" poweroff 2>/dev/null || true
    c_ylw "forzado poweroff de $vm"
  done
  c_grn "lab detenido."
}

cmd_restore() {
  for entry in "${LAB_VMS[@]}"; do
    local vm="${entry%%:*}"; vm_exists "$vm" || continue
    vm_running "$vm" && VBoxManage controlvm "$vm" poweroff 2>/dev/null || true
    if VBoxManage snapshot "$vm" list --machinereadable 2>/dev/null | grep -q "SnapshotName.*=\"$SNAP_BASE\""; then
      VBoxManage snapshot "$vm" restore "$SNAP_BASE" && c_grn "restaurada $vm -> '$SNAP_BASE'"
    else
      c_ylw "$vm sin snapshot '$SNAP_BASE'; nada que restaurar"
    fi
  done
}

cmd_status() {
  printf '%-18s %-10s %s\n' "VM" "ESTADO" "NICs"
  for entry in "${LAB_VMS[@]}"; do
    local vm="${entry%%:*}" st="ausente"
    vm_exists "$vm" || { printf '%-18s %-10s %s\n' "$vm" "$st" "-"; continue; }
    vm_running "$vm" && st="running" || st="apagada"
    printf '%-18s %-10s %s\n' "$vm" "$st" "$(vm_nics "$vm")"
  done
}

# ─── Dispatch ───────────────────────────────────────────────────────────────
case "${1:-}" in
  check)    cmd_check ;;
  wire)     cmd_wire ;;
  wan-on)   cmd_wan_on "${2:-}" ;;
  wan-off)  cmd_wan_off "${2:-}" ;;
  snapshot) cmd_snapshot ;;
  up)       cmd_up ;;
  down)     cmd_down ;;
  restore)  cmd_restore ;;
  status)   cmd_status ;;
  *) cat >&2 <<EOF
labnet-up.sh — laboratorio de VMs del curso sobre VirtualBox

  check          audita aislamiento de red (no arranca)
  wire           fuerza NIC de lab a intnet '$LABNET'
  wan-on  <vm>   da Internet a una VM (NIC2 NAT)
  wan-off <vm>   corta Internet de una VM
  snapshot       snapshot base '$SNAP_BASE' por VM
  up             check + arranca todas (headless)
  down           apaga todas
  restore        restaura cada VM a '$SNAP_BASE'
  status         estado y NICs

Edita el array LAB_VMS con los nombres EXACTOS de tus VMs (VBoxManage list vms).
Guía de uso completa: LABORATORIO-VM.md
EOF
     exit 1 ;;
esac
