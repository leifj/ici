#!/bin/bash
#
# This is an EXAMPLE of how ICI can be set up to run as soon as a request
# is created.
#

set -x
set -e

source /etc/ici/ici.conf

ICI_ISSUE_DAYS=${ICI_ISSUE_DAYS-'7'}

if [[ ! $ICI_CA_NAME ]]; then
    echo "$0: Environment variable ICI_CA_NAME not set"
    exit 1
fi

conf="${ICI_CA_ROOT}/${ICI_CA_NAME}/ca.config"
if [[ ! -f "${conf}" ]]; then
    echo "$0: CA configuration file ${conf} does not exist"
    exit 1
fi

req_dir="${ICI_CA_ROOT}/${ICI_CA_NAME}/requests"
if [[ ! -d "${req_dir}" ]]; then
    echo "$0: CA requests directory ${req_dir} does not exist"
    exit 1
fi

if [[ $ICI_START_PCSCD ]]; then
    /usr/sbin/pcscd
fi

# By setting waitpid to nothing here, the while loop will run once immediately at the startup of this service
waitpid=''

while [ 1 ]; do
    # Wait for the inotifywait started into the background by the last iteration of this loop (if any)
    if [ "x${waitpid}" != "x" ]; then
	wait $waitpid
    fi
    # Start a new inotifywait as soon as possible after the previous one terminates.
    # If this inofitywait terminates while we're issuing and publishing certificates below,
    # the 'wait' above will fall through immediately on the next iteration and we will
    # perform a new issue/publish right away. This minimises the window where we would miss
    # new events, but does not completely remove it. Don't know if perfection can be
    # achieved here using only shell commands.
    inotifywait -q -e close_write -e moved_to --exclude 'txt$' "${req_dir}"/{server,client,peer} &
    waitpid=$!

    # Adding -d to one of these invocations logs the openssl config contents once
    ici -d -v "${ICI_CA_NAME}" issue -d ${ICI_ISSUE_DAYS} -t server -- "${req_dir}/server/"
    ici -v "${ICI_CA_NAME}" issue -d ${ICI_ISSUE_DAYS} -t client -- "${req_dir}/client/"
    ici -v "${ICI_CA_NAME}" issue -d ${ICI_ISSUE_DAYS} -t peer -- "${req_dir}/peer/"

    ici -v "${ICI_CA_NAME}" publish req-resp "${ICI_CA_ROOT}/${ICI_CA_NAME}/out-certs"

    if [ "x${ICI_PUBLISH_GIT_REPO}" != "x" ]; then
	ici -v "${ICI_CA_NAME}" publish git "${ICI_PUBLISH_GIT_REPO}"
    fi
    if [ "x${ICI_PUBLISH_HTML_DIR}" != "x" ]; then
	ici -v "${ICI_CA_NAME}" publish html "${ICI_PUBLISH_HTML_DIR}"
    fi

    ici -v "${ICI_CA_NAME}" report
done
