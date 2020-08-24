#!/usr/bin/env bash
# THIS FILE IS PART OF THE CYLC SUITE ENGINE.
# Copyright (C) NIWA & British Crown (Met Office) & Contributors.
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
export REQUIRE_PLATFORM='loc:remote fs:shared'
. "$(dirname "$0")/test_header"
#-------------------------------------------------------------------------------
set_test_number 9
if ${CYLC_TEST_DEBUG:-false}; then ERR=2; else ERR=1; fi
#-------------------------------------------------------------------------------
# run through the shutdown - restart procedure
BASE_GLOBAL_CONFIG="
[scheduler]
    [[main loop]]
        plugins = health check, auto restart
        [[[auto restart]]]
            interval = PT2S
    [[events]]
        abort on inactivity = True
        abort on timeout = True
        inactivity = PT1M
        timeout = PT1M
[suite servers]
    run hosts = localhost, ${CYLC_TEST_HOST}"

TEST_NAME="${TEST_NAME_BASE}"
TEST_DIR="$HOME/cylc-run/" init_suite "${TEST_NAME}" - <<'__FLOW_CONFIG__'
[scheduler]
    [[parameters]]
        foo = 1..25
[scheduling]
    [[graph]]
        R1 = "task<foo> => task<foo+1>"
__FLOW_CONFIG__
# run suite on localhost normally
create_test_global_config '' "${BASE_GLOBAL_CONFIG}"
run_ok "${TEST_NAME}-suite-start" \
    cylc run "${SUITE_NAME}" --host=localhost -s 'FOO=foo' -v
cylc suite-state "${SUITE_NAME}" --task='task_foo01' \
    --status='succeeded' --point=1 --interval=1 --max-polls=20 >& $ERR

# condemn localhost
create_test_global_config '' "
${BASE_GLOBAL_CONFIG}
[suite servers]
    condemned hosts = $(hostname)
"
# test shutdown procedure - scan the first log file
FILE=$(cylc cat-log "${SUITE_NAME}" -m p |xargs readlink -f)
log_scan "${TEST_NAME}-shutdown" "${FILE}" 20 1 \
    'The Cylc suite host will soon become un-available' \
    'Suite shutting down - REQUEST(NOW-NOW)' \
    "Attempting to restart on \"${CYLC_TEST_HOST}\"" \
    "Suite now running on \"${CYLC_TEST_HOST}\""
LATEST_TASK=$(cylc suite-state "${SUITE_NAME}" -S succeeded \
    | cut -d ',' -f 1 | sort | tail -n 1 | sed 's/task_foo//')

# test restart procedure  - scan the second log file created on restart
poll_suite_restart
FILE=$(cylc cat-log "${SUITE_NAME}" -m p |xargs readlink -f)
log_scan "${TEST_NAME}-restart" "${FILE}" 20 1 \
    "Suite server: url=tcp://$(get_fqdn_by_host "${CYLC_TEST_HOST}")"
run_ok "${TEST_NAME}-restart-success" cylc suite-state "${SUITE_NAME}" \
    --task="$(printf 'task_foo%02d' $(( LATEST_TASK + 3 )))" \
    --status='succeeded' --point=1 --interval=1 --max-polls=20

# check the command the suite has been restarted with
run_ok "${TEST_NAME}-contact" cylc get-contact "${SUITE_NAME}"
grep_ok "cylc-restart ${SUITE_NAME} --host=${CYLC_TEST_HOST} --host=localhost" \
    "${TEST_NAME}-contact.stdout"

# stop suite
cylc stop "${SUITE_NAME}" --kill --max-polls=10 --interval=2 2>'/dev/null'
purge_suite "${SUITE_NAME}"
purge_suite_platform "${CYLC_TEST_PLATFORM}" "${SUITE_NAME}"

exit
