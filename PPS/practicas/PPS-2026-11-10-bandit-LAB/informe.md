# Informe de análisis estático — Bandit

**Alumno/a:** _______________________________________________
**Fecha:** 10 de noviembre de 2026
**Versión de Bandit:** _(escribe la que te sale con `bandit --version`)_

---

## 1. Informe inicial

Número de avisos con `bandit -r reservas`: __________

---

## 2. Tabla de triaje

Rellena una fila por cada aviso del informe inicial. Veredicto: VP (verdadero positivo), FP (falso positivo), INF (informativo).

| # | Fichero | Línea | Regla | Sev. | Conf. | Veredicto | Explicación (de dónde viene el dato / por qué es o no es un fallo) |
|---|---------|-------|-------|------|-------|-----------|----------------------------------------------------------------------|
| 1 |         |       |       |      |       |           |                                                                      |
| 2 |         |       |       |      |       |           |                                                                      |
| 3 |         |       |       |      |       |           |                                                                      |
| 4 |         |       |       |      |       |           |                                                                      |
| 5 |         |       |       |      |       |           |                                                                      |
| 6 |         |       |       |      |       |           |                                                                      |
| 7 |         |       |       |      |       |           |                                                                      |
| 8 |         |       |       |      |       |           |                                                                      |
| 9 |         |       |       |      |       |           |                                                                      |
|10 |         |       |       |      |       |           |                                                                      |

---

## 3. Correcciones realizadas

### SQLi — `buscar_reservas` (base_datos.py)

_(describe qué cambiaste y pega el fragmento de código corregido)_

### MD5 — `hashear_password` / `verificar_password` (autenticacion.py)

_(describe qué cambiaste; menciona la sal y por qué es necesaria)_

### Token — `generar_token_recuperacion` (utilidades.py)

_(¿qué módulo usaste en su lugar?)_

### Pickle — `leer_sesion` / `crear_sesion` (autenticacion.py)

_(describe el nuevo formato y cómo proteges contra manipulación)_

### shell=True — `comprobar_equipo` (utilidades.py)

_(¿cómo pasas el comando? ¿qué validación añadiste?)_

### assert — `eliminar_reserva` (base_datos.py)

_(¿con qué lo sustituiste? ¿qué excepción lanzas?)_

### ADMIN_PASSWORD (autenticacion.py)

_(¿cómo lees ahora la contraseña sin escribirla en el código?)_

### Falsos positivos marcados con `# nosec`

_(lista los identificadores que marcaste y justifica cada uno)_

---

## 4. El fallo que Bandit no vio

**Fichero:** `reservas/informes.py`
**Función:** `leer_informe`

**Tipo de fallo:** _(escribe el nombre y el número CWE)_

**Qué permite hacer:** _(explica con tus palabras qué se puede leer y desde dónde)_

**Por qué Bandit no lo detecta:** _(una o dos frases)_

**Corrección aplicada:** _(describe qué comprobación añadiste)_

---

## 5. Respuestas a las preguntas

**1.** ¿Por qué `bandit -r .` daba tantos avisos más que `bandit -r reservas`?

_(respuesta)_

**2.** ¿Qué diferencia hay entre severidad y confianza? Pon un ejemplo de esta práctica de cada uno.

_(respuesta)_

**3.** ¿Qué verdadero positivo desaparece con `-ll -ii`? ¿Qué te dice eso sobre filtrar por confianza?

_(respuesta)_

**4.** Explica uno de tus falsos positivos: qué vio Bandit y por qué en este código no es un fallo.

_(respuesta)_

**5.** ¿Por qué `assert` no sirve como control de acceso?

_(respuesta)_

**6.** ¿Qué fallo no detectó Bandit? ¿Por qué crees que no puede detectarlo?

_(respuesta)_
