#!/usr/bin/env sh

set -e

# Uploads a XAR file to a remote database server
## Expects the following environment variables:
# GITHUB_WORKSPACE - path to the checked out git project
# REMOTE_EDB_SERVER_USERNAME - username for authenticating to the remote database server
# REMOTE_EDB_SERVER_PASSWORD - password for authenticating to the remote database server
# REMOTE_EDB_SERVER_URL - URL of a remote database server to upload the XAR file into

curl --request PUT --basic --user "${REMOTE_EDB_SERVER_USERNAME}:${REMOTE_EDB_SERVER_PASSWORD}" --header 'Content-Type: application/expath+xar' --data-binary "@$GITHUB_WORKSPACE/target/${package-final-name}.xar" "${REMOTE_EDB_SERVER_URL}/rest${db-tmp-collection}/${package-final-name}.xar"
