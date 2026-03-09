# GNU MediaGoblin -- federated, autonomous media hosting
# Copyright (C) 2011, 2012 MediaGoblin contributors.  See AUTHORS.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
import logging

from mediagoblin import mg_globals, messages
from mediagoblin.auth.tools import register_user, create_basic_user
from mediagoblin.db.models import User, Privilege
from mediagoblin.decorators import allow_registration, auth_enabled
from mediagoblin.tools.translate import pass_to_ugettext as _
from mediagoblin.tools.response import redirect, render_to_response
from mediagoblin.plugins.sandstorm.models import SandstormUser

from random import getrandbits
from urllib.parse import unquote

_LOG = logging.getLogger(__name__)


def _get_user_name_field():
    for field in ("username", "slug", "url_slug"):
        if hasattr(User, field):
            return field
    return None


def _create_user_for_sandstorm(name):
    # Try the app-provided helper first because it can track schema changes.
    class _Field:
        def __init__(self, data):
            self.data = data

    class _Form:
        pass

    form = _Form()
    form.username = _Field(name)
    form.email = _Field("{0}@example.invalid".format(name))

    try:
        return create_basic_user(form)
    except (AttributeError, TypeError, ValueError) as exc:
        _LOG.warning(
            "Falling back to manual Sandstorm user creation for %r due to "
            "create_basic_user compatibility error: %s",
            name,
            exc,
        )
        user = User()
        name_field = _get_user_name_field()
        if name_field:
            setattr(user, name_field, name)
        if hasattr(user, "email"):
            user.email = "{0}@example.invalid".format(name)
        if hasattr(user, "pw_hash"):
            user.pw_hash = str(getrandbits(192))
        user.save()
        return user


def _add_missing_privileges(user, privileges):
    existing_ids = {priv.id for priv in user.all_privileges if priv is not None}
    for privilege in privileges:
        if privilege is None:
            continue
        if privilege.id in existing_ids:
            continue
        user.all_privileges.append(privilege)
        existing_ids.add(privilege.id)


@auth_enabled
def login(request):
    login_failed = False

    username = request.headers.get('X-Sandstorm-Username', None)
    user_id = request.headers.get('X-Sandstorm-User-Id', None)
    permissions = request.headers.get('X-Sandstorm-Permissions', None)

    if username != None:
        username = unquote(username)
    if permissions != None:
        permissions = unquote(permissions)

    default_privileges = None
    if username and user_id:
        suser = SandstormUser.query.filter_by(sandstorm_user_id=user_id).first()

        if not suser:
            if not mg_globals.app.auth:
                messages.add_message(
                    request,
                    messages.WARNING,
                    _('Sorry, authentication is disabled on this '
                      'instance.'))
                return redirect(request, 'index')

            name_field = _get_user_name_field()
            while name_field and User.query.filter(getattr(User, name_field) == username).count() > 0:
                username += '2'

            user = _create_user_for_sandstorm(username)

            default_privileges = [
                Privilege.query.filter(Privilege.privilege_name==u'commenter').first(),
                Privilege.query.filter(Privilege.privilege_name==u'reporter').first(),
                Privilege.query.filter(Privilege.privilege_name==u'active').first()]
        else:
            user = suser.user

        if 'admin' in permissions.split(','):
            default_privileges = [
                Privilege.query.filter(Privilege.privilege_name==u'commenter').first(),
                Privilege.query.filter(Privilege.privilege_name==u'reporter').first(),
                Privilege.query.filter(Privilege.privilege_name==u'active').first(),
                Privilege.query.filter(Privilege.privilege_name==u'admin').first(),
                Privilege.query.filter(Privilege.privilege_name==u'moderator').first(),
                Privilege.query.filter(Privilege.privilege_name==u'uploader').first()]

        if default_privileges:
            _add_missing_privileges(user, default_privileges)
        user.save()

        if not suser:
            suser = SandstormUser()
            suser.user_id = user.id
            suser.sandstorm_user_id = user_id
            suser.save()

        request.session['user_id'] = str(user.id)
        request.session.save()

    if request.form.get('next'):
        return redirect(request, location=request.form['next'])
    else:
        return redirect(request, "index")


@allow_registration
@auth_enabled
def register(request):
    return redirect(
        request,
        'mediagoblin.plugins.sandstorm.login')
