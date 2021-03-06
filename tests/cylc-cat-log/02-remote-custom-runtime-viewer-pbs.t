#!/bin/bash
# THIS FILE IS PART OF THE CYLC SUITE ENGINE.
# Copyright (C) 2008-2017 NIWA
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#-------------------------------------------------------------------------------
# Test "cylc cat-log" for viewing PBS runtime STDOUT/STDERR by a custom command
CYLC_TEST_IS_GENERIC=false
. "$(dirname "$0")/test_header"

RC_PREF='[test battery][batch systems][pbs]'
export CYLC_TEST_HOST="$( \
    cylc get-global-config -i "${RC_PREF}host" 2>'/dev/null')"
if [[ -z "${CYLC_TEST_HOST}" ]]; then
    skip_all '"[test battery][batch systems][pbs]host": not defined'
fi
ERR_VIEWER="$(cylc get-global-config -i "${RC_PREF}err viewer" 2>'/dev/null')"
OUT_VIEWER="$(cylc get-global-config -i "${RC_PREF}out viewer" 2>'/dev/null')"
if [[ -z "${ERR_VIEWER}" || -z "${OUT_VIEWER}" ]]; then
    skip_all '"[test battery][pbs]* viewer": not defined'
fi
export CYLC_TEST_DIRECTIVES="$( \
    cylc get-global-config -i "${RC_PREF}[directives]" 2>'/dev/null')"
set_test_number 2

install_suite "${TEST_NAME_BASE}" "${TEST_NAME_BASE}"

create_test_globalrc "" "
[hosts]
    [[${CYLC_TEST_HOST}]]
        [[[batch systems]]]
            [[[[pbs]]]]
                err viewer = ${ERR_VIEWER}
                out viewer = ${OUT_VIEWER}"
run_ok "${TEST_NAME_BASE}-validate" cylc validate "${SUITE_NAME}"
suite_run_ok "${TEST_NAME_BASE}" \
    cylc run --debug --no-detach --reference-test "${SUITE_NAME}"

purge_suite_remote "${CYLC_TEST_HOST}" "${SUITE_NAME}"
purge_suite "${SUITE_NAME}"
exit
