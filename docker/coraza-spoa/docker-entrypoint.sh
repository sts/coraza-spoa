#!/bin/sh

set -e

if [ $# -gt 0 ] && [ "$1" = "${1#-}" ]; then
	# First char isn't `-`, probably a `docker run -ti <cmd>`
	# Just exec and exit
	exec "$@"
	exit
fi

exec coraza-spoa --config-file /etc/coraza-spoa/config.yaml
