#!/bin/bash

set -e

		if [ -z "$LEARNINGLOCKER_DB_HOST" ]; then
			LEARNINGLOCKER_DB_HOST='mongo'
		else
			echo >&2 "  Connecting to LEARNINGLOCKER_DB_HOST ($LEARNINGLOCKER_DB_HOST)"
			echo >&2 '  instead of the linked mongodb container'
		fi

	if [ -z "$LEARNINGLOCKER_DB_HOST" ]; then
		echo >&2 'error: missing LEARNINGLOCKER_DB_HOST and MONGO_PORT_27017_TCP environment variables'
		echo >&2 '  Did you forget to --link some_mongo_container:mongo or set an external db'
		echo >&2 '  with -e LEARNINGLOCKER_DB_HOST=hostname:port?'
		exit 1
	fi

  # If we're linked to MongoDB and thus have credentials already, let's use them
  : ${LEARNINGLOCKER_DB_USER:=learninglocker}
  : ${LEARNINGLOCKER_DB_PASSWORD:-learninglocker}
  : ${LEARNINGLOCKER_DB_NAME:=learninglocker}

  if [ -z "$LEARNINGLOCKER_DB_PASSWORD" ]; then
    echo >&2 'error: missing required LEARNINGLOCKER_DB_PASSWORD environment variable'
    echo >&2 '  Did you forget to -e LEARNINGLOCKER_DB_PASSWORD=... ?'
    echo >&2
    echo >&2 '  (Also of interest might be LEARNINGLOCKER_DB_USER and LEARNINGLOCKER_DB_NAME.)'
    exit 1
  fi

  # Check if FQDN/HOSTNAME is set
  : ${LEARNINGLOCKER_URL:=$HOSTNAME}}
  if [ -z "$LEARNINGLOCKER_URL" ]; then
    echo >&2 'error: missing required LEARNINGLOCKER_URL/HOSTNAME environment variable'
    exit 1
  fi

  # Create learninglocker user
  echo "==> Creating user $LEARNINGLOCKER_DB_USER@$LEARNINGLOCKER_DB_PASSWORD on $LEARNINGLOCKER_DB_HOST/$LEARNINGLOCKER_DB_NAME"
  #cat > /tmp/createUser.js <<-EOF
  echo  "use $LEARNINGLOCKER_DB_NAME;" > /tmp/createUser.js
  echo  "db.createUser({ user: '$LEARNINGLOCKER_DB_USER', pwd: '$LEARNINGLOCKER_DB_PASSWORD', roles:[{ role: 'readWrite', db: '$LEARNINGLOCKER_DB_NAME' }] });" >> /tmp/createUser.js
  #EOF
  cat /tmp/createUser.js | mongo \
    --username "$MONGO_INITDB_ROOT_USERNAME" \
    --password "$MONGO_INITDB_ROOT_PASSWORD" \
    "${LEARNINGLOCKER_DB_HOST}/admin"
    #< /tmp/createUser.js
  #rm /tmp/createUser.js
