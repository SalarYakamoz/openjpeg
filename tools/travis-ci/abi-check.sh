#!/bin/bash

# This script executes the abi-check step when running under travis-ci (in run step)

# Set-up some bash options
set -o nounset   ## set -u : exit the script if you try to use an uninitialised variable
set -o errexit   ## set -e : exit the script if any statement returns a non-true return value
set -o pipefail  ## Fail on error in pipe
set -o xtrace    ## set -x : Print a trace of simple commands and their arguments after they are expanded and before they are executed.

# Exit if not ABI check
if [ "${OPJ_CI_ABI_CHECK:-}" != "1" ]; then
	exit 0
fi

OPJ_UPLOAD_ABI_REPORT=0
OPJ_LIMIT_ABI_BUILDS="-limit 2"
if [ "${TRAVIS_REPO_SLUG:-}" != "" ]; then
	if [ "$(echo "${TRAVIS_REPO_SLUG}" | sed 's/\(^.*\)\/.*/\1/')" == "uclouvain" ] && [ "${TRAVIS_PULL_REQUEST:-}" == "false" ]; then
		# Upload report
		OPJ_UPLOAD_ABI_REPORT=1
		# Build full report
		OPJ_LIMIT_ABI_BUILDS=
	fi
fi

OPJ_SOURCE_DIR=$(cd $(dirname $0)/../.. && pwd)


mkdir ${HOME}/abi-check
cd ${HOME}/abi-check
# Let's get tools not available with apt
mkdir tools
wget -qO - https://tools.ietf.org/tools/rfcdiff/rfcdiff-1.42.tgz | tar -xz
mv rfcdiff-1.42 ${PWD}/tools/rfcdiff
wget -qO - https://github.com/lvc/installer/archive/0.2.tar.gz | tar -xz
mkdir ${PWD}/tools/abi-tracker
make -C installer-0.2 install prefix=${PWD}/tools/abi-tracker target=abi-tracker
rm -rf installer-0.2
export PATH=${PWD}/tools/rfcdiff:${PWD}/tools/abi-tracker/bin:$PATH
mkdir tracker
cp -f ${OPJ_SOURCE_DIR}/tools/abi-tracker/openjpeg.json ./tracker/openjpeg.json
cd tracker

# Let's create all we need
abi-monitor ${OPJ_LIMIT_ABI_BUILDS} -get openjpeg.json
cp -rf ${OPJ_SOURCE_DIR} src/openjpeg/current
abi-monitor ${OPJ_LIMIT_ABI_BUILDS} -build openjpeg.json
abi-tracker -build openjpeg.json

EXIT_CODE=0

# Check API
abi-compliance-checker -l openjpeg -old $(find ./abi_dump/openjpeg/2.1 -name '*.dump') -new $(find ./abi_dump/openjpeg/current -name '*.dump') -header openjpeg.h -api -s || EXIT_CODE=1

# Check ABI
abi-compliance-checker -l openjpeg -old $(find ./abi_dump/openjpeg/2.1 -name '*.dump') -new $(find ./abi_dump/openjpeg/current -name '*.dump') -header openjpeg.h -abi -s || EXIT_CODE=1

rm -rf src installed

if [ ${OPJ_UPLOAD_ABI_REPORT} -eq 1 ]; then
	echo "TODO: Where to upload the report"
fi

exit $EXIT_CODE
