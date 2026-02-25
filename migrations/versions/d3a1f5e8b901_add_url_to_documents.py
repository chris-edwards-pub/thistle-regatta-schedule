"""Add url to documents, make filename nullable

Revision ID: d3a1f5e8b901
Revises: c82d4c9ce2d5
Create Date: 2026-02-15
"""

import sqlalchemy as sa
from alembic import op

revision = "d3a1f5e8b901"
down_revision = "c82d4c9ce2d5"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("documents", sa.Column("url", sa.String(length=500), nullable=True))
    op.alter_column(
        "documents", "original_filename", existing_type=sa.String(255), nullable=True
    )
    op.alter_column(
        "documents", "stored_filename", existing_type=sa.String(255), nullable=True
    )


def downgrade():
    op.alter_column(
        "documents", "stored_filename", existing_type=sa.String(255), nullable=False
    )
    op.alter_column(
        "documents", "original_filename", existing_type=sa.String(255), nullable=False
    )
    op.drop_column("documents", "url")
