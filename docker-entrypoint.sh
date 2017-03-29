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

	if [ ! -z "$LOAD_BALANCER" ]; then
		sed -i 's/App::before(function($request) {});/App::before(function($request) {Request::setTrustedProxies( [ $request->getClientIp() ] ); });/g' /var/www/html/app/filters.php
	fi

	echo 'opcache.enable_cli = Off
	zend.enable_gc = 0
	opcache.fast_shutdown=0' > /usr/local/etc/php/conf.d/z-cli.ini

	# If we're linked to MongoDB and thus have credentials already, let's use them
	: ${LEARNINGLOCKER_DB_USER:=learninglocker}
	: ${LEARNINGLOCKER_DB_PASSWORD:-learninglocker}
	: ${LEARNINGLOCKER_DB_NAME:=learninglocker}

	# if [ -z "$LEARNINGLOCKER_DB_PASSWORD" ]; then
	# 	echo >&2 'error: missing required LEARNINGLOCKER_DB_PASSWORD environment variable'
	# 	echo >&2 '  Did you forget to -e LEARNINGLOCKER_DB_PASSWORD=... ?'
	# 	echo >&2
	# 	echo >&2 '  (Also of interest might be LEARNINGLOCKER_DB_USER and LEARNINGLOCKER_DB_NAME.)'
	# 	exit 1
	# fi

	# Check if FQDN/HOSTNAME is set
	: ${APP_URL:=$HOSTNAME}}
	if [ -z "$APP_URL" ]; then
			echo >&2 'error: missing required APP_URL/HOSTNAME environment variable'
		exit 1
	fi

	# Create learninglocker user
	# echo "==> Creating user $LEARNINGLOCKER_DB_USER@$LEARNINGLOCKER_DB_PASSWORD on $LEARNINGLOCKER_DB_HOST/$LEARNINGLOCKER_DB_NAME"
	# cat > /tmp/createUser.js <<-EOF
	# 	use $LEARNINGLOCKER_DB_NAME;
	# 	db.createUser({ user: '$LEARNINGLOCKER_DB_USER', pwd: '$LEARNINGLOCKER_DB_PASSWORD', roles:[{ role: 'readWrite', db: '$LEARNINGLOCKER_DB_NAME' }] });
	# EOF
	# mongo \
		# --username "$MONGO_ADMIN_USER" \
		# --password "$MONGO_ADMIN_PASSWORD" \
		# "${LEARNINGLOCKER_DB_HOST}/admin" < /tmp/createUser.js
	# rm /tmp/createUser.js

	# Setup database connection to mongodb
	if [ ! -e app/config/local/database.php ]; then
		if [ -z "$LEARNINGLOCKER_DB_REPLICA_SET" ]; then
			cat > app/config/local/database.php <<-EOF
				<?php
				return [
					'connections' => [
						'mongodb' => [
							'driver'   => 'mongodb',
							'host'     => '${LEARNINGLOCKER_DB_HOST}',
							'port'     => 27017,
							'database' => '$LEARNINGLOCKER_DB_NAME',
							'username' => '${LEARNINGLOCKER_DB_USER}',
							'password' => '${LEARNINGLOCKER_DB_PASSWORD}'
						],
					]
				];
			EOF
		else
			cat > app/config/local/database.php <<-EOF
				<?php
				return [
					'connections' => [
						'mongodb' => [
							'driver'   => 'mongodb',
							'host'     => array(${LEARNINGLOCKER_DB_HOST}),
							'port'     => 27017,
							'database' => '$LEARNINGLOCKER_DB_NAME',
							'username' => '${LEARNINGLOCKER_DB_USER}',
							'password' => '${LEARNINGLOCKER_DB_PASSWORD}',
							'options' => array('replicaSet' => '${LEARNINGLOCKER_DB_REPLICA_SET}')
						],
					]
				];
			EOF
		fi
		echo "Running the migration command"
		php artisan migrate
		echo "Migration command finished"
	fi

	# 'username' => '$LEARNINGLOCKER_DB_USER',
	# 'password' => '$LEARNINGLOCKER_DB_PASSWORD',

	# Configure secret key for encryption
	APP_SECRET_KEY=${APP_SECRET_KEY:-CHANGEME12345678}
	if [ ! -e app/config/local/app.php ]; then
		cat > app/config/local/app.php <<-EOF
			<?php
			return [
				'key' => '$APP_SECRET_KEY',
				'url' => 'https://$APP_URL'
			];
		EOF
	fi

	# STMP server configuration
    SMTP_PRETEND=${SMTP_SERVER:-false}
	SMTP_SERVER=${SMTP_SERVER:-smtp.sendgrid.net}
	SMTP_PORT=${SMTP_PORT:-25}
	SMTP_USER=${SMTP_USER:-username}
	SMTP_PASSWORD=${SMTP_PASSWORD:-password}
	EMAIL_FROM_NAME=${EMAIL_FROM_NAME:-Learning Locker LRS Docker Container}
	EMAIL_FROM_ADDRESS=${EMAIL_FROM_ADDRESS:-admin@email.com}

	# Configure SMTP server
	if [ ! -e app/config/local/mail.php ]; then
		cat > app/config/local/mail.php <<-EOF
		<?php
		return [
			'pretend' => '$SMTP_PRETEND',
			'username' => '$SMTP_USER',
			'password' => '$SMTP_PASSWORD',
			'host' => '$SMTP_SERVER',
			'port' => '$SMTP_PORT',
			'from' => [
				'address' => '$EMAIL_FROM_ADDRESS',
				'name' => '$EMAIL_FROM_NAME'
			]
		];
		EOF
	fi
echo "starting"
exec "$@"
