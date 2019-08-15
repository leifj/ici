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

while [ 1 ]; do
    # Wait for a new CSR to appear in any of the three request directories.
    # NOTE: This is a simple example - if another CSR appears while issuing and publishing
    #       below, the next iteration of the while ĺoop won't trigger on that second CSR,
    #       since it is already in the request directory when this inotifywait command sets up.
    inotifywait -q -e close_write -e moved_to "${req_dir}"/{server,client,peer}

    ici -v "${ICI_CA_NAME}" issue -d ${ICI_ISSUE_DAYS} -t server -- "${req_dir}/server/"
    ici -v "${ICI_CA_NAME}" issue -d ${ICI_ISSUE_DAYS} -t client -- "${req_dir}/client/"
    ici -v "${ICI_CA_NAME}" issue -d ${ICI_ISSUE_DAYS} -t peer -- "${req_dir}/peer/"

    if [ "x${ICI_PUBLISH_GIT_REPO}" != "x" ]; then
	ici -v "${ICI_CA_NAME}" publish git "${ICI_PUBLISH_GIT_REPO}"
    fi
    if [ "x${ICI_PUBLISH_HTML_DIR}" != "x" ]; then
	ici -v "${ICI_CA_NAME}" publish html "${ICI_PUBLISH_HTML_DIR}"
    fi
    ici -v "${ICI_CA_NAME}" publish req-resp "${ICI_CA_ROOT}/${ICI_CA_NAME}/out-certs"

    ici -v "${ICI_CA_NAME}" report
done
