from datetime import date

from flask import flash, redirect, render_template, request, url_for
from flask_login import current_user, login_required

from app import db
from app.models import Document, Regatta, RSVP, User
from app.regattas import bp


@bp.route("/")
@login_required
def index():
    today = date.today()
    upcoming = (
        Regatta.query.filter(Regatta.start_date >= today)
        .order_by(Regatta.start_date)
        .all()
    )
    past = (
        Regatta.query.filter(Regatta.start_date < today)
        .order_by(Regatta.start_date.desc())
        .all()
    )
    users = User.query.filter(User.invite_token.is_(None)).order_by(User.display_name).all()
    return render_template("index.html", upcoming=upcoming, past=past, users=users)


@bp.route("/regattas/new", methods=["GET", "POST"])
@login_required
def create():
    if not current_user.is_admin:
        flash("Access denied.", "error")
        return redirect(url_for("regattas.index"))

    if request.method == "POST":
        return _save_regatta(None)

    return render_template("regatta_form.html", regatta=None)


@bp.route("/regattas/<int:regatta_id>/edit", methods=["GET", "POST"])
@login_required
def edit(regatta_id: int):
    if not current_user.is_admin:
        flash("Access denied.", "error")
        return redirect(url_for("regattas.index"))

    regatta = db.session.get(Regatta, regatta_id)
    if not regatta:
        flash("Regatta not found.", "error")
        return redirect(url_for("regattas.index"))

    if request.method == "POST":
        return _save_regatta(regatta)

    return render_template("regatta_form.html", regatta=regatta)


@bp.route("/regattas/<int:regatta_id>/delete", methods=["POST"])
@login_required
def delete(regatta_id: int):
    if not current_user.is_admin:
        flash("Access denied.", "error")
        return redirect(url_for("regattas.index"))

    regatta = db.session.get(Regatta, regatta_id)
    if regatta:
        db.session.delete(regatta)
        db.session.commit()
        flash(f"Regatta '{regatta.name}' deleted.", "success")
    return redirect(url_for("regattas.index"))


@bp.route("/regattas/<int:regatta_id>/rsvp", methods=["POST"])
@login_required
def rsvp(regatta_id: int):
    status = request.form.get("status", "").lower()
    if status not in ("yes", "no", "maybe"):
        flash("Invalid RSVP status.", "error")
        return redirect(url_for("regattas.index"))

    existing = RSVP.query.filter_by(
        regatta_id=regatta_id, user_id=current_user.id
    ).first()

    if existing:
        existing.status = status
    else:
        db.session.add(
            RSVP(regatta_id=regatta_id, user_id=current_user.id, status=status)
        )

    db.session.commit()
    return redirect(url_for("regattas.index"))


def _save_regatta(regatta: Regatta | None):
    name = request.form.get("name", "").strip()
    location = request.form.get("location", "").strip()
    location_url = request.form.get("location_url", "").strip()
    start_date_str = request.form.get("start_date", "")
    end_date_str = request.form.get("end_date", "")
    notes = request.form.get("notes", "").strip()

    if not name or not location or not start_date_str:
        flash("Name, location, and start date are required.", "error")
        return render_template("regatta_form.html", regatta=regatta)

    try:
        start_date = date.fromisoformat(start_date_str)
        end_date = date.fromisoformat(end_date_str) if end_date_str else None
    except ValueError:
        flash("Invalid date format.", "error")
        return render_template("regatta_form.html", regatta=regatta)

    if regatta is None:
        regatta = Regatta(created_by=current_user.id)
        db.session.add(regatta)

    regatta.name = name
    regatta.location = location
    regatta.location_url = location_url or None
    regatta.start_date = start_date
    regatta.end_date = end_date
    regatta.notes = notes or None

    db.session.commit()
    flash(f"Regatta '{name}' saved.", "success")
    return redirect(url_for("regattas.index"))
