#!/bin/bash

# FROM_DB_HOST, FROM_DB_PORT_FROM_DB_USER, FROM_DB_PASS
# TO_DB_HOST, TO_DB_PORT_TO_DB_USER, TO_DB_PASS
# DATABASE_NAMES, TO_DOCKER_CONTAINER
# (Required empty line at the end of the file)
envFile=".env"

if [ -f "$envFile" ]; then
	while read line; do
		eval $line
	done < $envFile
else
	echo "No .env file found"
	exit 1
fi

for db_name in ${DATABASE_NAMES[@]}; do
	echo "Migrating: $db_name"
	BUILD_PATH="build/${db_name}.sql"

	if [ -f "$BUILD_PATH" ]; then
		rm $BUILD_PATH
	fi

	RESTART_DB="DROP DATABASE IF EXISTS \"${db_name}\" WITH (FORCE); CREATE DATABASE \"${db_name}\";"
	echo $RESTART_DB > $BUILD_PATH

	pg_dump -O "host=${FROM_DB_HOST} port=${FROM_DB_PORT} dbname=${db_name} user=${FROM_DB_USER} password=${FROM_DB_PASS}" >> $BUILD_PATH

	TO_CONNECT_URI="postgresql://${TO_DB_USER}:${TO_DB_PASS}@${TO_DB_HOST}:${TO_DB_PORT}"
	TO_CONNECT_URI_DB="${TO_CONNECT_URI}/${db_name}"

	if [ -n "$TO_DOCKER_CONTAINER" ]; then
		echo $RESTART_DB | docker exec -i "${TO_DOCKER_CONTAINER}" psql "${TO_CONNECT_URI}"
		cat $BUILD_PATH | docker exec -i "${TO_DOCKER_CONTAINER}" psql "${TO_CONNECT_URI_DB}"
	else
		echo $RESTART_DB | psql "${TO_CONNECT_URI}"
		cat $BUILD_PATH | psql "${TO_CONNECT_URI_DB}"
	fi
done