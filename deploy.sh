#!/bin/bash

set -e

USAGE="deploy.sh -d -i [config]"

DEPENDENCIES=false

while getopts "di" opt; do
    case "$opt" in
        d)
            DEPENDENCIES=true
            ;;
        i)
            INITIALIZE=true
            ;;
    esac
done
shift "$((OPTIND-1))"

if [ "$#" -ne 1 ]; then
  echo "$USAGE"
  exit 1
fi

CONFIG=$1

parse_yaml() {
   local prefix=$2
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
      }
   }'
}

CONFIG_FILE="./config/config.${CONFIG}.yml"

eval $(parse_yaml ${CONFIG_FILE} "config_")

HOST=$config_league_api_deploy_host
USER=$config_league_api_deploy_user
DOCROOT=$config_league_api_docroot

RSYNC_EXCLUDE=""

rsync -ruvz --files-from "deploy.files" . "${USER}@${HOST}:${DOCROOT}"

if [ "$INITIALIZE" = true ]; then
  ssh ${USER}@${HOST} "cd ${DOCROOT} && cp config/config.${CONFIG}.yml config.yml && cp credentials.EXAMPLE.yml credentials.yml"

  echo -e "NOTE: credentials.yml file updated.  You will need to modify this file and add valid credentials."
fi

if [ "$DEPENDENCIES" = true ]; then
  ssh ${USER}@${HOST} "cd ${DOCROOT} && ./build.sh ${CONFIG}"
fi

exit 0
