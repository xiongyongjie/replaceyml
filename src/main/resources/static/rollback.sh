#!/bin/bash

FILE_SERVER=""
APP_NAME=""
APP_PORT=""
APP_TYPE="war"
APP_VERSION="-1"

root=$(id -u)
if [ "$root" -ne 0 ] ;then
    echo must run as root
    exit 1
fi


script::preCheck()
{
  ns=()
  for file in `ls /opt/deploybak/"$APP_NAME"`
   do
      TMPFILENAME="$file"
      ns[$nIn]=$TMPFILENAME
      nIn=`expr $nIn + 1`
  done
  len=${#ns[@]}
  if [ "$len" -le "1" ]; then
   echo "错误: 备份数量小于2,回滚失败!"
   exit 0
  fi
  if [ "$APP_VERSION" != "-1" ]; then
     filePath=/opt/deploybak/"$APP_NAME"/"$APP_NAME"_"$APP_VERSION"."$APP_TYPE"
     if [ ! -f "$filePath" ]; then 
      echo "错误: 未找到指定版本"
      exit 0
     fi
  fi
}

script::stopApp()
{
    mkdir -p /opt/war /opt/deploy/"$APP_NAME" /opt/deploybak/"$APP_NAME" /tmp/tomcat
    if [ ! -n "$APP_TYPE" ]; then
     APP_TYPE="war"
    fi
    if [ ! -n "$APP_VERSION" ]; then
     APP_VERSION="-1"
    fi
      DID=`ps -ef | grep "/opt/deploy/$APP_NAME"| grep -v "grep"|awk {'print $2'}`
    if [ -n "$DID" ]; then
      if [ "$APP_TYPE" == "war" ]; then
       pid=`/usr/sbin/lsof -i :$APP_PORT|grep -v "PID"|awk '{print $2}'`
       if [ -n "$pid" ]; then
         sh /opt/deploy/"$APP_NAME"/tomcat/bin/shutdown.sh
         sleep 3s
         kill -9 $pid
       fi
      elif [ "$APP_TYPE" == "jar" ]; then
       kill -9 $DID
      fi
    fi
}

script::sort()
{
 local _arr=(`echo $1 | cut -d " "  --output-delimiter=" " -f 1-`)
 local _n_arr=${#_arr[@]}
 for (( i=0 ; i<${#arr[@]} ; i++ ))
	do
	  for (( j=${#arr[@]} - 1 ; j>i ; j-- ))
	  do
	    if  [[ ${arr[j]} -lt ${arr[j-1]} ]]; then
	       t=${arr[j]}
	       arr[j]=${arr[j-1]}
	       arr[j-1]=$t
	    fi
	  done
	done
}

script::rollBack()
{
  ns=()
  nIn=0
  for file in `ls /opt/deploybak/"$APP_NAME"`
   do
      TMPFILENAME="$file"
      n=`echo "$TMPFILENAME" | sed 's/[a-zA-Z-]*_\([0-9]*\).*/\1/g'`
      ns[$nIn]=$n
      nIn=`expr $nIn + 1`
  done
  script::sort "$(echo ${ns[@]})"
  len=${#ns[@]}
  if [ "$APP_VERSION" == "-1" ]; then
    lastIn=`expr $len - 2`
    lastEle=${ns[lastIn]}
    cp /opt/deploybak/"$APP_NAME"/"$APP_NAME"_"$lastEle"."$APP_TYPE" /opt/deploy/"$APP_NAME"/"$APP_NAME"."$APP_TYPE"
    else
     filePath=/opt/deploybak/"$APP_NAME"/"$APP_NAME"_"$APP_VERSION"."$APP_TYPE"
     if [ ! -f "$filePath" ]; then 
      echo "错误: 未找到指定版本"
      exit 0
     fi
     cp /opt/deploybak/"$APP_NAME"/"$APP_NAME"_"$APP_VERSION"."$APP_TYPE" /opt/deploy/"$APP_NAME"/"$APP_NAME"."$APP_TYPE"
  fi
}

script::deploy()
{
    if [ "$APP_TYPE" == "war" ]; then
     cp /opt/deploy/"$APP_NAME"/"$APP_NAME"."$APP_TYPE" /opt/deploy/"$APP_NAME"/tomcat/webapps/"$APP_NAME"."$APP_TYPE"
     sh /opt/deploy/"$APP_NAME"/tomcat/bin/startup.sh
     echo "appName: $APP_NAME, appPort: $APP_PORT, Start-up success!"
    elif [ "$APP_TYPE" == "jar" ]; then
     dateTime=$(date +%Y%m%d-%H%M%S)
     nohup java -jar /opt/deploy/"$APP_NAME"/"$APP_NAME"."$APP_TYPE" > /opt/deploy/"$APP_NAME"/"$APP_NAME"_"$dateTime".log 2>&1 &
		fi     
}
script::initStart()
{
  echo "(1/4) 回滚准备检查"
  script::preCheck
  echo "(2/4) 服务应用开始停机."
  script::stopApp
  echo "(3/4) 服务应用开始回滚"
  script::rollBack
  echo "(4/4) 服务应用开始启动"
  script::deploy
}

main()
{
    FILE_SERVER=$1
    APP_NAME=$2
    APP_PORT=$3
    APP_TYPE=$4
    APP_VERSION=$5
    script::initStart
}

main $@
