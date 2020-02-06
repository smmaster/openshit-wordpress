#!/bin/bash

set -x
set -eo pipefail


WORDPRESS_REPOSITORY_URL="https://github.com/smmaster/openshit-wordpress.git"


create_project(){
    project=$1
    oc new-project  $project
    oc new-app templates/wordpress.json  -p WORDPRESS_REPOSITORY_URL=$WORDPRESS_REPOSITORY_URL
}

start_build(){

	oc start-build --from-dir=. wordpress  --follow
}

wait_for_build(){
        until oc get po|grep wordpress-db|grep 1/.*Running; do sleep 5; done
        until oc get po|grep wordpress.*build  |grep  Completed; do sleep 5; done
}

get_wordpress_host(){

	HOST=$(oc get routes wordpress -o jsonpath='{.spec.host}')
	echo http://$HOST
}


import_db(){

    WORDPRESS_URL=$1
    perl -pe 's|http://localhost/trade|'"${WORDPRESS_URL}/trade"'|g'   sql/trade.sql  > sql/trade2.sql
    MYSQL_POD=$(oc get po -l deployment=wordpress-db-1 -o custom-columns=POD:.metadata.name --no-headers)
    oc cp sql/trade2.sql $MYSQL_POD:/tmp/trade.sql
    oc  rsh    $MYSQL_POD sh -c '/opt/rh/rh-mysql57/root/usr/bin/mysql -u root wordpress </tmp/trade.sql'

}


###################MAIN###################################

create_project trade
wait_for_build
WORDPRESS_URL=$(get_wordpress_host)
import_db $WORDPRESS_URL
echo "#############################################################################################"
echo  $WORDPRESS_URL/trade
