# Laboratorio IC 11/11: reglas propias y línea temporal

Material de la práctica del 11 de noviembre. Todo es inventado: la empresa, el portal de
nóminas, los usuarios y las IP. Los rangos 203.0.113.0/24 y 198.51.100.0/24 están reservados
para documentación y no pertenecen a nadie.

| Fichero | Para qué sirve |
|---|---|
| `portal-nominas-SINTETICO.log` | Registro del portal de nóminas de `srv-web01` del lunes 9 de noviembre |
| `auth-srv-web01-SINTETICO.log` | Registro de SSH del mismo servidor y el mismo día |
| `local_decoder.xml` | Esqueleto del decodificador que vas a completar |
| `local_rules.xml` | Esqueleto de las reglas que vas a completar |
| `resumen_logtest.py` | Convierte la salida de `wazuh-logtest` en una tabla |
| `simular-portal.sh` | Genera en tu equipo, con `logger`, unos eventos del portal |
| `plantilla-reglas.md` | Plantilla de la entrega |

## Contexto del caso

- `srv-web01` es el servidor web de la empresa. Tiene un portal interno de nóminas.
- La red interna es 10.20.0.0/24. Desde fuera solo se debería entrar al portal por excepción.
- El director trabaja desde casa los lunes por la mañana. Su conexión tiene la IP fija
  198.51.100.23 y está autorizada por escrito.
- `rrhh` es la cuenta del departamento de personal; exporta datos de nóminas a menudo.
- `tecnico` es el administrador del servidor; entra por SSH con clave desde 10.20.0.5.
- Los registros usan la hora local de España, sin zona horaria, como el syslog clásico.
