"""miweb: reservas del aula de informática.

Es la web base del proyecto del curso. La construyes y la proteges en PPS,
la atacas desde tu Kali en HE y vigilas lo que pasa con tu Wazuh en IC.
Tiene fallos de seguridad a propósito. Todos los datos son inventados.
"""
import sqlite3
from functools import wraps

from flask import (Flask, abort, flash, g, redirect, render_template, request,
                   session, url_for)
from werkzeug.middleware.proxy_fix import ProxyFix
from werkzeug.security import check_password_hash, generate_password_hash

from . import bd, config, registro


def crear_app(**ajustes) -> Flask:
    app = Flask(__name__)
    app.config.update(
        SECRET_KEY=config.SECRET_KEY,
        DEBUG=config.DEBUG,
        BD=str(config.BD),
        REGISTRO_SEGURIDAD=config.REGISTRO_SEGURIDAD,
        ADMIN_CLAVE=config.ADMIN_CLAVE,
    )
    app.config.update(ajustes)
    # TODO 4 — Lanza RuntimeError si falta SECRET_KEY o ADMIN_CLAVE.
    #           La app no debe arrancar sin secretos. Ejemplo:
    #           for obligatoria in ("SECRET_KEY", "ADMIN_CLAVE"):
    #               if not app.config.get(obligatoria):
    #                   raise RuntimeError(f"Falta la variable MIWEB_{obligatoria}")

    # nginx está delante y nos pasa la IP real del cliente en X-Forwarded-For.
    app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1)

    registro.configurar(app.config["REGISTRO_SEGURIDAD"])
    app.teardown_appcontext(bd.cerrar)
    with app.app_context():
        bd.iniciar(app.config["ADMIN_CLAVE"])

    _rutas(app)
    return app


def requiere_sesion(vista):
    @wraps(vista)
    def envoltura(*args, **kwargs):
        if g.usuario_id is None:
            registro.evento("sin_sesion", 302)
            return redirect(url_for("login"))
        return vista(*args, **kwargs)
    return envoltura


def _rutas(app: Flask) -> None:

    @app.before_request
    def cargar_usuario():
        g.usuario_id = session.get("usuario_id")
        g.usuario_nombre = session.get("usuario_nombre")
        g.rol = session.get("rol")

    @app.route("/")
    def inicio():
        return render_template("inicio.html")

    @app.route("/salud")
    def salud():
        return {"estado": "ok"}

    @app.route("/registro", methods=["GET", "POST"])
    def registro_usuario():
        if request.method == "POST":
            nombre = request.form.get("nombre", "").strip()
            clave = request.form.get("clave", "")
            if not nombre or len(clave) < 8:
                flash("El nombre es obligatorio y la contraseña debe tener 8 caracteres o más.")
                return render_template("registro.html"), 400
            try:
                bd.conexion().execute("INSERT INTO usuarios (nombre, hash) VALUES (?, ?)",
                                      (nombre, generate_password_hash(clave)))
                bd.conexion().commit()
            except sqlite3.IntegrityError:
                flash("Ese nombre de usuario ya existe.")
                return render_template("registro.html"), 409
            registro.evento("registro", usuario=nombre)
            flash("Cuenta creada. Ya puedes entrar.")
            return redirect(url_for("login"))
        return render_template("registro.html")

    @app.route("/login", methods=["GET", "POST"])
    def login():
        if request.method == "POST":
            nombre = request.form.get("nombre", "")
            clave = request.form.get("clave", "")
            fila = bd.conexion().execute(
                "SELECT id, nombre, hash, rol FROM usuarios WHERE nombre = ?", (nombre,)
            ).fetchone()
            if fila is None:
                registro.evento("login_fallido", 401, usuario=nombre,
                                detalle="usuario inexistente")
                flash("Ese usuario no existe.")
                return render_template("login.html"), 401
            if not check_password_hash(fila["hash"], clave):
                # TODO 5 — Este detalle guarda la contraseña en el log de seguridad.
                #           Cámbialo a: detalle="contraseña incorrecta"
                registro.evento("login_fallido", 401, usuario=nombre,
                                detalle=f"contraseña incorrecta: {clave}")
                flash("Contraseña incorrecta.")
                return render_template("login.html"), 401
            session.clear()
            session["usuario_id"] = fila["id"]
            session["usuario_nombre"] = fila["nombre"]
            session["rol"] = fila["rol"]
            registro.evento("login_ok", 302, usuario=fila["nombre"])
            return redirect(url_for("mis_reservas"))
        return render_template("login.html")

    @app.route("/logout")
    def logout():
        registro.evento("logout", 302)
        session.clear()
        return redirect(url_for("inicio"))

    @app.route("/reservas")
    @requiere_sesion
    def mis_reservas():
        filas = bd.conexion().execute(
            "SELECT id, aula, fecha, franja FROM reservas WHERE usuario_id = ? ORDER BY fecha",
            (g.usuario_id,),
        ).fetchall()
        return render_template("reservas.html", reservas=filas)

    @app.route("/reservas/nueva", methods=["GET", "POST"])
    @requiere_sesion
    def nueva_reserva():
        if request.method == "POST":
            datos = {c: request.form.get(c, "").strip()
                     for c in ("aula", "fecha", "franja", "motivo")}
            if not all(datos.values()):
                flash("Rellena todos los campos.")
                return render_template("nueva.html"), 400
            cur = bd.conexion().execute(
                "INSERT INTO reservas (usuario_id, aula, fecha, franja, motivo) "
                "VALUES (?, ?, ?, ?, ?)",
                (g.usuario_id, datos["aula"], datos["fecha"], datos["franja"], datos["motivo"]),
            )
            bd.conexion().commit()
            registro.evento("reserva_creada", 302, detalle=f"id={cur.lastrowid}")
            return redirect(url_for("ver_reserva", reserva_id=cur.lastrowid))
        return render_template("nueva.html")

    @app.route("/reservas/<int:reserva_id>")
    @requiere_sesion
    def ver_reserva(reserva_id):
        fila = bd.conexion().execute(
            "SELECT r.*, u.nombre AS propietario FROM reservas r "
            "JOIN usuarios u ON u.id = r.usuario_id WHERE r.id = ?", (reserva_id,)
        ).fetchone()
        if fila is None:
            abort(404)
        if fila["usuario_id"] != g.usuario_id:
            registro.evento("reserva_ajena", detalle=f"id={reserva_id} propietario={fila['propietario']}")
        return render_template("reserva.html", r=fila)

    @app.route("/buscar")
    @requiere_sesion
    def buscar():
        texto = request.args.get("q", "")
        consulta = ("SELECT id, aula, fecha, franja FROM reservas "
                    f"WHERE usuario_id = {g.usuario_id} AND motivo LIKE '%{texto}%'")
        try:
            filas = bd.conexion().execute(consulta).fetchall()
        except sqlite3.Error as error:
            registro.evento("error_bd", 500, detalle=f"q={texto} error={error}")
            return render_template("error.html", mensaje=f"Error en la consulta: {error}"), 500
        registro.evento("busqueda", detalle=f"q={texto}")
        return render_template("reservas.html", reservas=filas, busqueda=texto)

    @app.route("/admin")
    @requiere_sesion
    def admin():
        if g.rol != "admin":
            registro.evento("acceso_denegado", 403)
            abort(403)
        usuarios = bd.conexion().execute("SELECT id, nombre, rol FROM usuarios").fetchall()
        return render_template("admin.html", usuarios=usuarios)

    @app.errorhandler(403)
    def prohibido(_e):
        return render_template("error.html", mensaje="No tienes permiso para ver esto."), 403

    @app.errorhandler(404)
    def no_encontrado(_e):
        registro.evento("no_encontrado", 404)
        return render_template("error.html", mensaje="Esa página no existe."), 404
