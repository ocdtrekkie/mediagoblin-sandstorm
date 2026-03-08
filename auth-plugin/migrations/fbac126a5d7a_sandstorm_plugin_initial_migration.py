"""sandstorm plugin initial migration

Revision ID: fbac126a5d7a
Revises: cc3651803714
Create Date: 2026-03-08 04:23:55.707376

"""

# revision identifiers, used by Alembic.
revision = 'fbac126a5d7a'
down_revision = 'cc3651803714'
branch_labels = ('sandstorm_plugin',)
depends_on = None

from alembic import op
import sqlalchemy as sa


def upgrade():
    op.create_table(
        'sandstorm__user',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('sandstorm_user_id', sa.Unicode(), nullable=True, unique=True, index=True),
        sa.Column('user_id', sa.Integer(), sa.ForeignKey('core__users.id'), nullable=True),
        sa.PrimaryKeyConstraint('id')
    )


def downgrade():
    op.drop_table('sandstorm__user')
