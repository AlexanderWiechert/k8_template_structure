#!/bin/bash

set -e

GITURL="gitlab.com"
PRODUCTNAME=$1 #BSP: MDEstartet
SERVICENAME=$2 #BSP: acs-server
TOKEN="*"
HTTPAUTH="username:password"

next () {

read -p "Continue (y/n)?" choice
case "$choice" in
  y|Y ) echo "yes";;
  n|N ) echo "no";;
  * ) echo "invalid";;
esac

}

if [ -z $PRODUCTNAME ] || [ -z $ SERVICENAME ]; then
    echo -e "Script muss mit zwei Parametern aufgerufen werden.\nBespiel: $0 MDESTARTER acs-server"; exit 1
fi

echo "#IMPORT new Rootgroup"
curl -s -X POST --header "PRIVATE-TOKEN:$TOKEN" --form "name=$PRODUCTNAME" --form "path=$PRODUCTNAME" --form "file=@../templates/root_project_import.tar.gz" https://$GITURL/api/v4/groups/import

echo "#GET ID of new root group"
RG_ID=$(curl -s -X GET --header "PRIVATE-TOKEN:$TOKEN" "https://$GITURL/api/v4/groups/$PRODUCTNAME" | jq '.id')
echo $RG_ID

echo "#Create Subgroups . wait 10 seconds for gitlab to complete import"
sleep 10

echo "#create kubernetes subgroup"
curl -s -X POST --header "PRIVATE-TOKEN:$TOKEN" --header "Content-Type: application/json" --data '{"name": "kubernetes", "path": "kubernetes", "description": "kubernetes subgroup for '$PRODUCTNAME'" }' https://$GITURL/api/v4/groups?parent_id=$RG_ID

echo "#GET ID of new kubernetes group"
KG_ID=$(curl -s -X GET --header "PRIVATE-TOKEN:$TOKEN" "https://$GITURL/api/v4/groups/$PRODUCTNAME%2Fkubernetes" | jq '.id')
echo $KG_ID

echo "#create servicegroup"
curl -s -X POST --header "PRIVATE-TOKEN:$TOKEN" --header "Content-Type: application/json" --data '{"name": "'$SERVICENAME'", "path": "'$SERVICENAME'", "description": "'$SERVICENAME' subgroup for '$PRODUCTNAME'" }' https://$GITURL/api/v4/groups?parent_id=$KG_ID
echo "#GET ID of new stage group"
SVCG_ID=$(curl -s -X GET --header "PRIVATE-TOKEN:$TOKEN" "https://$GITURL/api/v4/groups/$PRODUCTNAME%2Fkubernetes%2F$SERVICENAME" | jq '.id')
echo $SVCG_ID

echo "#create DEV1 group"
STAGES=( DEV1 DEV2 PROD01 )
for i in "${STAGES[@]}"
do
	curl -s -X POST --header "PRIVATE-TOKEN:$TOKEN" --header "Content-Type: application/json" --data '{"name": "'$i'", "path": "'$i'", "description": "'$SERVICENAME'/'$i' subgroup for '$PRODUCTNAME'" }' https://$GITURL/api/v4/groups?parent_id=$SVCG_ID

done

for i in "${STAGES[@]}"
do
  echo "#GET ID of new $i stage group"
  export $i'_ID'=$(curl -s -X GET --header "PRIVATE-TOKEN:$TOKEN" "https://$GITURL/api/v4/groups/$PRODUCTNAME%2Fkubernetes%2F$SERVICENAME%2F$i" | jq '.id')
done

echo "#create repository for Penny"
curl -s -X POST --header "PRIVATE-TOKEN:$TOKEN" \
--header "Content-Type: application/json" \
--data '{ "name": "'$SERVICENAME-py'", "path": "'$SERVICENAME-py'", "description": "service project for '$PRODUCTNAME'", "namespace_id": "'$DEV1_ID'", "initialize_with_readme": "true"}' \
https://$GITURL/api/v4/projects/

curl -s -X POST --header "PRIVATE-TOKEN:$TOKEN" \
--header "Content-Type: application/json" \
--data '{ "name": "'$SERVICENAME-py'", "path": "'$SERVICENAME-py'", "description": "service project for '$PRODUCTNAME'", "namespace_id": "'$DEV2_ID'", "initialize_with_readme": "true"}' \
https://$GITURL/api/v4/projects/

curl -s -X POST --header "PRIVATE-TOKEN:$TOKEN" \
--header "Content-Type: application/json" \
--data '{ "name": "'$SERVICENAME-py'", "path": "'$SERVICENAME-py'", "description": "service project for '$PRODUCTNAME'", "namespace_id": "'$PROD01_ID'", "initialize_with_readme": "true"}' \
https://$GITURL/api/v4/projects/


for i in "${STAGES[@]}"
do
  echo "#Import example project for penny"
  if [ -d $i/deploy_py ]; then
    rm -rf $i/deploy_py
  fi
  git clone ssh://git@gitlab.rewe.local:5022/mosys/mdestarter/kubernetes/acs-server/$i/deploy_py.git $i/deploy_py
  cd $i/deploy_py
  git remote set-url origin https://$HTTPAUTH@$GITURL/$PRODUCTNAME/kubernetes/$SERVICENAME/$i/$SERVICENAME-py.git
  git branch -M main
  git push -uf origin main
done


#echo "#create namespace project"
#curl -s -X POST --header "PRIVATE-TOKEN:$TOKEN" \
#--header "Content-Type: application/json" \
#--data '{ "name": "create-namespace", "path": "create-namespace", "description": "namespace project for '$PRODUCTNAME'", "namespace_id": "'$KG_ID'", "initialize_with_readme": "true"}' \
#https://$GITURL/api/v4/projects/

echo "#Import new namespace project"
if [ -d create-namespace ]; then
  rm -rf create-namespace
fi
git clone ssh://git@gitlab.rewe.local:5022/mosys/mdestarter/kubernetes/create-namespace.git
git remote set-url origin https://$HTTPAUTH@$GITURL/$PRODUCTNAME/kubernetes/$SERVICENAME/create-namespace.git
git branch -M main
git push -uf origin main

echo "#Import new helm-chart project"
if [ -d helm-chart ]; then
  rm -rf helm-chart
fi
git clone ssh://git@gitlab.rewe.local:5022/mosys/mdestarter/kubernetes/acs-server/helm-chart.git
git remote set-url origin https://$HTTPAUTH@$GITURL/$PRODUCTNAME/kubernetes/$SERVICENAME/helm-chart.git
git branch -M main
git push -uf origin main
