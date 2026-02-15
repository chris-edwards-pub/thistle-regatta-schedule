from flask import Blueprint

bp = Blueprint("regattas", __name__)

from app.regattas import routes  # noqa: E402, F401
