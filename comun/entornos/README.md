# Entorno de laboratorio del curso — listo desde el minuto uno

Objetivo: que el **día 1** de cada módulo el aula ya tenga los objetivos y las
herramientas levantadas, sin perder una sesión en instalar. Todo el curso gira sobre un
único escenario ficticio, **xest** (`*.xest.local`), que PPS construye, HE ataca e IC
defiende.

## Topología

```
                 RED DE AULA AISLADA (VLAN de laboratorio, sin salida a la red del centro)
  ┌───────────────┐     ┌───────────────────┐     ┌────────────────────────┐
  │ Estación       │     │ objetivo.xest.local│     │ SOC (SOC/plataforma)   │
  │ del alumno      │────▶│ portal-soc + APIs  │◀────│ Wazuh + Suricata +     │
  │ (Kali/attacker) │     │ Juice Shop, DVWA…  │     │ TheHive + Cortex + MISP│
  └───────────────┘     └───────────────────┘     └────────────────────────┘
        HE ataca              PPS construye              IC detecta/responde
```

Regla de oro (la enseña HE UT1 y aplica a todo el curso): **nada de esto se ejecuta
contra la red del centro ni contra Internet**. Solo la VLAN aislada.

## Tres piezas

| Pieza | Dónde | Levantar con |
|---|---|---|
| **Objetivos vulnerables** (PPS/HE) | `objetivos/docker-compose.yml` (aquí) | `docker compose up -d` |
| **Caja de herramientas del atacante** | VM Kali o contenedor `attacker` | ver `attacker-toolbox.md` |
| **Objetivo VM completa** (HE) | Metasploitable en VirtualBox | ver `objetivos/metasploitable.md` |
| **SOC / plataforma defensiva** (IC) | `~/xest-lab/2026-2027/SOC/plataforma/` | `docker compose up -d` |

## Laboratorio de VMs (Kali + Metasploitable)

Cuando el objetivo es una máquina completa (no un contenedor), el lab se gestiona
con [`labnet-up.sh`](labnet-up.sh): cablea las VMs a la red aislada `labnet`,
garantiza que no tocan la red del centro (rechaza el modo *bridged*) y permite
levantar, restaurar y parar el escenario con un comando. Incluye `wan-on`/`wan-off`
para dar Internet controlado solo al descargar herramientas.

- Guía de uso completa: [LABORATORIO-VM.md](LABORATORIO-VM.md).
- Objetivo Metasploitable (qué es, descarga directa y uso): [objetivos/metasploitable.md](objetivos/metasploitable.md).

## Preparación del profesor — checklist de arranque (una vez)

- [ ] Máquina anfitriona del aula con Docker + Docker Compose v2 y ≥16 GB RAM
      (el stack SOC pesa; ver requisitos de Wazuh).
- [ ] Clonar/actualizar el repo: `cd ~/xest-lab/2026-2027 && git pull`.
- [ ] Levantar objetivos: `cd objetivos && docker compose up -d && docker compose ps`.
- [ ] Resolver `*.xest.local` en el aula: entrada DNS en el router del lab, o
      `/etc/hosts` desplegado a las estaciones (`objetivos/hosts-aula`).
- [ ] VM Kali plantilla exportada (`.ova`) para clonado rápido, o contenedor `attacker`.
- [ ] Adaptadores Wi-Fi con modo monitor (HE UT3) y Proxmark3/Flipper (HE UT4) inventariados.
- [ ] Prueba de humo de objetivos: `bash smoke-test.sh` (aquí) — debe dar todo OK antes de clase.
- [ ] **Prueba del arsenal** en la estación Kali: `bash check-arsenal.sh` — verifica que las 66
      herramientas de HE (OSINT + ataque) están instaladas; con sugerencia de instalación por
      cada una que falte. Por bloques: `check-arsenal.sh osint` · `web` · `ut6` · `ut7` · `wifi`.

## Convención para el aula

Cada estación resuelve estos nombres (vía DNS del lab o `hosts`):

```
10.10.10.10   objetivo.xest.local portal-soc.xest.local
10.10.10.11   juice.xest.local
10.10.10.12   dvwa.xest.local
10.10.10.20   soc.xest.local
```

Ajusta las IP a tu direccionamiento real; `hosts-aula` es solo plantilla.
