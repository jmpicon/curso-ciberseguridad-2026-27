# Metasploitable 2 — máquina víctima para prácticas

## Qué es y para qué sirve

**Metasploitable 2** es una máquina virtual Linux (Ubuntu 8.04) **deliberadamente
vulnerable**, publicada por Rapid7 (los autores de Metasploit) para practicar
pentesting en un entorno legal y controlado. Trae a propósito servicios viejos y
mal configurados: FTP con backdoor, Samba explotable, un `distccd` ejecutable
remotamente, Tomcat con credenciales por defecto, MySQL/PostgreSQL abiertos,
servicios UnrealIRCd troyanizados, aplicaciones web vulnerables (DVWA, Mutillidae,
phpMyAdmin), etc.

En el curso es el **objetivo de red clásico** para HE: donde aprendes a escanear
con `nmap`, identificar servicios, buscar el exploit adecuado en Metasploit y
conseguir acceso — y donde, desde el SOC (IC), ves cómo se detecta ese ataque.

Complementa a los objetivos web en Docker (Juice Shop, DVWA en
`objetivos/docker-compose.yml`): aquellos son aplicaciones web; Metasploitable es
una **máquina entera** con muchos servicios de red que atacar.

> **Para qué NO sirve:** es de 2012 y muy antigua. Es ideal para *aprender el
> método* (enumerar → identificar → explotar → post-explotación), no para
> representar un objetivo moderno. Para técnicas actuales usamos los objetivos
> Docker del curso y, más adelante, GOAD (Active Directory).

---

## Descarga directa

Proyecto oficial en SourceForge (archivo único, ~865 MB):

- Página del proyecto: https://sourceforge.net/projects/metasploitable/files/Metasploitable2/
- Enlace directo del fichero:
  **https://sourceforge.net/projects/metasploitable/files/Metasploitable2/metasploitable-linux-2.0.0.zip/download**
- Documentación de Rapid7: https://docs.rapid7.com/metasploit/metasploitable-2/

Desde terminal:
```bash
curl -L -o metasploitable2.zip \
  "https://sourceforge.net/projects/metasploitable/files/Metasploitable2/metasploitable-linux-2.0.0.zip/download"
unzip metasploitable2.zip        # obtienes una carpeta Metasploitable2 con un .vmdk
```

El ZIP contiene un disco **VMware** (`.vmdk`) y sus ficheros de configuración.
VirtualBox puede usar el `.vmdk` directamente (abajo).

> **Credenciales por defecto:** usuario `msfadmin` / contraseña `msfadmin`
> (también válidas por SSH una vez tenga IP en el lab).

---

## Importar en VirtualBox

No hay que "instalar" nada: se crea una VM nueva y se le engancha el disco `.vmdk`
ya descargado.

1. VirtualBox → **Nueva** → Tipo *Linux*, versión *Ubuntu (32-bit)*, nombre
   `metasploitable`.
2. En el disco duro, elige **"Usar un archivo de disco duro virtual existente"** y
   selecciona el `Metasploitable.vmdk` del ZIP.
3. **Red: red interna `labnet`** (nunca puente/bridged). Con el script:
   ```bash
   ./labnet-up.sh wire          # la deja en intnet labnet
   ./labnet-up.sh check         # confirma el aislamiento
   ```
4. Arranca, entra con `msfadmin`/`msfadmin` y ponle IP del lab (`10.10.10.13`):
   ```bash
   sudo ifconfig eth0 10.10.10.13 netmask 255.255.255.0
   ```
5. **Snapshot limpio** antes de atacarla: `./labnet-up.sh snapshot`.

> **Aislamiento (obligatorio):** Metasploitable está hecha para ser vulnerable;
> exponerla a una red real es un riesgo serio. Úsala **solo** en `intnet labnet`.
> Si necesitas Internet puntual para algo, `wan-on` y luego `wan-off` antes de
> atacar (ver [../LABORATORIO-VM.md](../LABORATORIO-VM.md)).

---

## Nota de arquitectura (importante)

Metasploitable 2 es **x86 (32-bit)**. Funciona en VirtualBox sobre PCs Intel/AMD
(los equipos del aula). En **Mac con Apple Silicon (M1–M5)**, VirtualBox solo
ejecuta invitados ARM, así que Metasploitable **no arranca** ahí. Alternativas en
ese caso:

- Usar los objetivos web del curso en Docker (multiplataforma): Juice Shop y DVWA.
- Emular x86 con UTM/QEMU (muy lento, solo si no hay otra opción).

---

## Primer contacto desde Kali (ejemplo)

Con ambas VMs en `labnet` y la víctima en `10.10.10.13`:

```bash
# 1) Enumerar servicios
nmap -sV -p- 10.10.10.13

# 2) Un clásico para entender el método: backdoor de vsftpd 2.3.4
msfconsole -q
msf6 > use exploit/unix/ftp/vsftpd_234_backdoor
msf6 > set RHOSTS 10.10.10.13
msf6 > run
```

El objetivo didáctico no es "sacar la shell", es que sepas **explicar** qué
servicio era vulnerable, por qué, qué huella deja el ataque y cómo se detectaría
desde el SOC. Eso es lo que se evalúa.
