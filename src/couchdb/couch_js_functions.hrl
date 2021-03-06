% Licensed under the Apache License, Version 2.0 (the "License"); you may not
% use this file except in compliance with the License.  You may obtain a copy of
% the License at
%
%   http://www.apache.org/licenses/LICENSE-2.0
%
% Unless required by applicable law or agreed to in writing, software
% distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
% WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
% License for the specific language governing permissions and limitations under
% the License.

-define(AUTH_DB_DOC_VALIDATE_FUNCTION, <<"
    function(newDoc, oldDoc, userCtx) {
        if (newDoc._deleted === true) {
            // allow deletes by admins and matching users
            // without checking the other fields
            if ((userCtx.roles.indexOf('_admin') !== -1) ||
                (userCtx.name == oldDoc.name)) {
                return;
            } else {
                throw({forbidden: 'Only admins may delete other user docs.'});
            }
        }

        if ((oldDoc && oldDoc.type !== 'user') || newDoc.type !== 'user') {
            throw({forbidden : 'doc.type must be user'});
        } // we only allow user docs for now

        if (!newDoc.name) {
            throw({forbidden: 'doc.name is required'});
        }

        if (newDoc.roles && !isArray(newDoc.roles)) {
            throw({forbidden: 'doc.roles must be an array'});
        }

        if (newDoc._id !== ('org.couchdb.user:' + newDoc.name)) {
            throw({
                forbidden: 'Doc ID must be of the form org.couchdb.user:name'
            });
        }

        if (oldDoc) { // validate all updates
            if (oldDoc.name !== newDoc.name) {
                throw({forbidden: 'Usernames can not be changed.'});
            }
        }

        if (newDoc.password_sha && !newDoc.salt) {
            throw({
                forbidden: 'Users with password_sha must have a salt.' +
                    'See /_utils/script/couch.js for example code.'
            });
        }

        if (userCtx.roles.indexOf('_admin') === -1) {
            if (oldDoc) { // validate non-admin updates
                if (userCtx.name !== newDoc.name) {
                    throw({
                        forbidden: 'You may only update your own user document.'
                    });
                }
                // validate role updates
                var oldRoles = oldDoc.roles.sort();
                var newRoles = newDoc.roles.sort();

                if (oldRoles.length !== newRoles.length) {
                    throw({forbidden: 'Only _admin may edit roles'});
                }

                for (var i = 0; i < oldRoles.length; i++) {
                    if (oldRoles[i] !== newRoles[i]) {
                        throw({forbidden: 'Only _admin may edit roles'});
                    }
                }
            } else if (newDoc.roles.length > 0) {
                throw({forbidden: 'Only _admin may set roles'});
            }
        }

        // no system roles in users db
        for (var i = 0; i < newDoc.roles.length; i++) {
            if (newDoc.roles[i][0] === '_') {
                throw({
                    forbidden:
                    'No system roles (starting with underscore) in users db.'
                });
            }
        }

        // no system names as names
        if (newDoc.name[0] === '_') {
            throw({forbidden: 'Username may not start with underscore.'});
        }
    }
">>).


-define(REP_DB_DOC_VALIDATE_FUN, <<"
    function(newDoc, oldDoc, userCtx) {
        if (newDoc.user_ctx) {

            function reportError(error_msg) {
                log('Error writing document ' + newDoc._id +
                    ' to replicator DB: ' + error_msg);
                throw({forbidden: error_msg});
            }

            var user_ctx = newDoc.user_ctx;

            if (typeof user_ctx !== 'object') {
                reportError('The user_ctx property must be an object.');
            }

            if (!(user_ctx.name === null ||
                    (typeof user_ctx.name === 'undefined') ||
                    ((typeof user_ctx.name === 'string') &&
                        user_ctx.name.length > 0))) {
                reportError('The name property of the user_ctx must be a ' +
                    'non-empty string.');
            }

            if (user_ctx.roles && !isArray(user_ctx.roles)) {
                reportError('The roles property of the user_ctx must be ' +
                    'an array of strings.');
            }

            if (user_ctx.roles) {
                for (var i = 0; i < user_ctx.roles.length; i++) {
                    var role = user_ctx.roles[i];

                    if (typeof role !== 'string' || role.length === 0) {
                        reportError('Each role must be a non-empty string.');
                    }
                    if (role[0] === '_') {
                        reportError('System roles (starting with underscore) ' +
                            'are not allowed.');
                    }
                }
            }
        }
    }
">>).
