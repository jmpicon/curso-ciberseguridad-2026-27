# Laboratorio de VMs — Kali + objetivos vulnerables (VirtualBox)

Esta guía es para cuando el objetivo no es un contenedor Docker (Juice Shop,
DVWA, ya en `objetivos/`), sino una **máquina virtual completa y vulnerable**
—típicamente **Metasploitable** (ver [objetivos/metasploitable.md](objetivos/metasploitable.md))—
a la que atacamos desde una VM **Kali**.

Lo gestiona el script [`labnet-up.sh`](labnet-up.sh): cablea las VMs a la red
aislada del lab, las aísla de la red del centro y te deja levantar, restaurar y
parar el escenario con un comando.

> **Regla de oro del curso:** nada del laboratorio se ejecuta contra la red del
> centro ni contra Internet. Solo la red aislada del lab. El script la hace
> cumplir: rechaza arrancar cualquier VM con la tarjeta en modo *bridged*.

---

## 1. La red del lab

Todas las VMs van a una **red interna** de VirtualBox llamada `labnet`
(`10.10.10.0/24`), la misma convención que el escenario xest. Una red interna
**no tiene contacto con tu Wi-Fi/Ethernet real**: las VMs se ven entre ellas y
con nadie más.

| Modo de red VirtualBox | ¿Internet? | ¿Toca tu red real? | ¿Las VMs se ven entre sí? |
|---|---|---|---|
| `intnet` (lo que usa el lab) | No | **No** | Sí, dentro de `labnet` |
| `nat` (solo para descargar) | Sí (salida) | **No** | No |
| `bridged` | Sí | **SÍ — prohibido** | Sí (en tu red real) |

El único peligroso es **bridged**: pone la VM en tu red física con IP propia. El
gate del script lo bloquea. **NAT no expone tu red**: solo da salida a Internet.

---

## 2. Internet: cuándo sí y cuándo no

Necesitas Internet para **descargar e instalar herramientas** (actualizar Kali,
bajar la imagen de Metasploitable, `apt`, metapaquetes…). Pero una víctima con
Internet durante el ejercicio podría, si la comprometes de verdad, salir hacia
fuera. Por eso:

- **Kali (atacante):** puede tener Internet permanente. Es tu máquina de trabajo.
- **Víctimas (Metasploitable, etc.):** Internet **solo para aprovisionar**; se
  desconecta durante la práctica ofensiva.

El script lo gestiona con dos comandos (añaden/retiran una segunda tarjeta NAT):

```bash
./labnet-up.sh wan-on  metasploitable   # dale Internet para descargar/actualizar
# ... instalas lo que necesites ...
./labnet-up.sh wan-off metasploitable   # córtalo: queda solo en la red del lab
```

---

## 3. IP en el lab (sin DHCP)

La red `labnet` no reparte IPs por sí sola. Dos caminos:

### a) IP estática en cada VM (rápido)
**Kali** → `10.10.10.50`:
```bash
sudo nmcli con mod "Wired connection 1" ipv4.method manual \
  ipv4.addresses 10.10.10.50/24 && sudo nmcli con up "Wired connection 1"
```
**Metasploitable** → `10.10.10.13` (coincide con la convención de `hosts-aula`):
```bash
# dentro de Metasploitable (login msfadmin / msfadmin):
sudo ifconfig eth0 10.10.10.13 netmask 255.255.255.0
```

### b) pfSense como gateway (completo)
VM pfSense con `nic1=intnet labnet` (LAN `10.10.10.1`, con servidor DHCP) y
`nic2=nat` (WAN). Da IP y, si quieres, salida a Internet **filtrada** para todo
el lab. Descoméntala como `"pfSense:fw"` en el array `LAB_VMS` del script.

---

## 4. Uso del script, paso a paso

```bash
# 1) Ajusta los nombres de tus VMs en el array LAB_VMS del script
#    (VBoxManage list vms  te los da exactos).

# 2) Cablea todas a la red aislada:
./labnet-up.sh wire

# 3) Comprueba el aislamiento (debe decir "Gate superado"):
./labnet-up.sh check

# 4) Punto de restauración limpio, ANTES de romper nada:
./labnet-up.sh snapshot

# 5) Arranca el lab (vuelve a pasar el gate antes de encender):
./labnet-up.sh up

#    ... prácticas: Kali ataca a la víctima, observas en el SOC ...

# 6) Vuelve todo a estado limpio para el siguiente grupo/intento:
./labnet-up.sh restore

# 7) Apaga el lab al terminar:
./labnet-up.sh down
```

`./labnet-up.sh status` te enseña en cualquier momento el estado y las tarjetas
de cada VM.

---

## 5. Descargar el script suelto

Si solo quieres el script sin clonar todo el repo:

```bash
curl -O https://raw.githubusercontent.com/jmpicon/curso-ciberseguridad-2026-27/main/comun/entornos/labnet-up.sh
chmod +x labnet-up.sh
```

---

## 6. Errores y avisos frecuentes

- **`The machine is not mutable (state is Saved)`**: la VM está suspendida, no
  apagada. Ciérrala del todo (apágala desde la GUI o `VBoxManage controlvm <vm>
  poweroff`) antes de cambiarle la red.
- **El gate falla con "FUGA ... bridged"**: alguna VM tiene la tarjeta en modo
  adaptador puente. Cámbiala a red interna: `./labnet-up.sh wire`.
- **La víctima no responde al ping desde Kali**: revisa que ambas estén en
  `intnet labnet` (`status`) y que tengan IP en `10.10.10.0/24` (§3).
- **Apple Silicon (M1–M5)**: VirtualBox solo ejecuta invitados ARM. Metasploitable
  es x86 y **no arranca** ahí; ver la nota de arquitectura en
  [objetivos/metasploitable.md](objetivos/metasploitable.md).
