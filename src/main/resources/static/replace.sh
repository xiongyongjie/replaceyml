#!/bin/bash

FILE_SERVER=""
FILE_NAME=""
WORK_DIR=""
PROFILE=""

#root=$(id -u)
#if [ "$root" -ne 0 ] ;then
#    echo must run as root
#    exit 1
#fi


script::down()
{
  fstr=`echo $FILE_SERVER | cut -d \: -f 1`
  #="$fstr":"6768"
  #result=$(curl -l -H "Content-type: application/json" -X POST -d '{"filePath":"'$FILE_NAME'"}' http://$httpServer/gitlab/$PROFILE)
  #result=$(curl -l -H "Content-type: application/json" -X GET -d '{"filePath":"'xxx'"}' http://172.16.10.170:9988/bootstrap-template.yml)
  #if [ "$result" == "" ]; then
  #  exit 1
  #fi
  #v=$(echo $result | sed 's/\"//g') result is filename:bootstrap_template.yml
  #curl -L http://$FILE_SERVER/conf/$v > /tmp/$v
  curl -L http://192.168.1.171:9988/bootstrap-template.yml > /tmp/bootstrap_template.yml
  echo "(2/2) 配置替换"
  v="bootstrap_template.yml"
  script::replace $v
}

script::replace()
{
   echo "replace start:$1"
   nIn=0
   if [ "$1" != "" ]; then
   echo "p1:$1"
     for f in `find $WORK_DIR -name "bootstrap.yml"`
       do
	     echo "f:$f"
         tAppName=$(grep -A 1 'application:' $f | tail -1)
         echo "..........> $tAppName"
         appName=$(echo $tAppName | sed 's/^[a-z]*: //g')
         #if [ "$appName" == "#APPLICATION_NAME#" ]; then 
         # break
         #fi
         echo "替换应用: $appName"
         echo "$f"
         \cp -rf /tmp/$1 $f
         sed -i 's/APPLICATION_REPLACE_NAME/'$appName'/g' $f
         sed -i 's/PROFILES_REPLACE_NAME/'$PROFILE'/g' $f     
         nIn=`expr $nIn + 1`
       done
   fi
   if [ "$nIn" -le "0" ]; then
     echo "替换失败!"
     exit 1
   fi  
}

script::initStart()
{
  echo "(1/2) 配置下载."
  script::down
}

main()
{
    FILE_SERVER=$1
    FILE_NAME=$2
    WORK_DIR=$3
    PROFILE=$4
    script::initStart
}

main $@
