#!/bin/bash

FILE_SERVER=""
APP_NAME=""
APP_PORT=""
APP_TYPE="war"

#root=$(id -u)
#if [ "$root" -ne 0 ] ;then
#    echo must run as root
#    exit 1
#fi

script::installcheck()
{
    mkdir -p /home/war /home/jar /home/deploy/"$APP_NAME" /home/deploybak/"$APP_NAME" /tmp/tomcat
    if [ ! -n "$APP_TYPE" ]; then
      APP_TYPE="war"
    fi
    DID=`ps -ef | grep "/home/deploy/$APP_NAME"| grep -v "grep"|awk {'print $2'}`
    if [ ! -n "$DID" ]; then
      if [ "$APP_TYPE" == "war" ]; then
        pid=`/usr/sbin/lsof -i :$APP_PORT|grep -v "PID"|awk '{print $2}'`
        if [ ! -n "$pid" ]; then
           echo "第一次初始化tomcat"
           script::newTomcat
        fi
      fi
    fi
        
    if [ -n "$DID" ]; then
      if [ "$APP_TYPE" == "war" ]; then
        pid=`/usr/sbin/lsof -i :$APP_PORT|grep -v "PID" | awk '{print $2}'`
        if [ -z "$pid" ]; then
          #sh /home/deploy/"$APP_NAME"/tomcat/bin/shutdown.sh
          #kill -9 $pid
          sleep 1s
          spid=`/usr/sbin/lsof -i :$APP_PORT|grep -v "PID" | awk '{print $2}'`
        if [ -z "$spid" ]; then
          kill -9 $spid
        fi
          script::newTomcat
        fi
      elif [ "$APP_TYPE" == "jar" ]; then
        echo "kill -9 $DID"
      fi
    fi
    DID=`ps -ef | grep "/home/deploy/$APP_NAME"| grep -v "grep"|awk {'print $2'}`
    if [ -n "$DID" ]; then
      kill -9 $DID
    fi
}

script::newTomcat()
{
     #curl -L http://$FILE_SERVER/tar/tomcat.tar.gz > /home/soft/tomcat.tar.gz
	 
     rm -rf /home/deploy/"$APP_NAME" && mkdir -p /home/deploy/"$APP_NAME"
     tar -zxf /home/soft/tomcat.tar.gz -C /home/deploy/"$APP_NAME"
     mv /home/deploy/"$APP_NAME"/apache-tomcat-* /home/deploy/"$APP_NAME"/tomcat
     sed -i "s/8080/$APP_PORT/g" /home/deploy/"$APP_NAME"/tomcat/conf/server.xml
     sed -i "s/8009/$[$APP_PORT+10000]/g" /home/deploy/"$APP_NAME"/tomcat/conf/server.xml
     sed -i "s/8005/$[$APP_PORT+10020]/g" /home/deploy/"$APP_NAME"/tomcat/conf/server.xml
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

script::backup()
{
  ns=()
  nIn=0
  for file in `ls /home/deploybak/"$APP_NAME"`
   do
      n=`echo "$file" | sed 's/[a-zA-Z-]*_\([0-9]*\).*/\1/g'`
      ns[$nIn]=$n
      nIn=`expr $nIn + 1`
  done
  script::sort "$(echo ${ns[@]})"
  len=${#ns[@]}
  addIn=1
  if [ "$len" -ge "1" ]; then
   lastIn=`expr $len - 1`
   lastEle=${ns[lastIn]}
   addIn=`expr $lastEle + 1`
  fi
  if [ "$APP_TYPE" == "war" ]; then
    cp /home/war/"$APP_NAME"/target/"$APP_NAME"."$APP_TYPE" /home/deploybak/"$APP_NAME"/"$APP_NAME"_"$addIn"."$APP_TYPE"
  elif [ "$APP_TYPE" == "jar" ]; then
    cp /home/jar/"$APP_NAME"."$APP_TYPE" /home/deploybak/"$APP_NAME"/"$APP_NAME"_"$addIn"."$APP_TYPE"
  fi
  
}

script::deploy()
{
    
    if [ "$APP_TYPE" == "war" ]; then
     	pid=`/usr/sbin/lsof -i :$APP_PORT|grep -v "PID" | awk '{print $2}'`
  	echo "pid is $pid"
  	if [ -z "$pid" ]; then
    		sh /home/deploy/"$APP_NAME"/tomcat/bin/shutdown.sh
    		sleep 3s
    		kill -9 $pid
 	fi
    	cp /home/$APP_TYPE/"$APP_NAME"/target/"$APP_NAME"."$APP_TYPE" /home/deploy/$APP_NAME/tomcat/webapps/ROOT."$APP_TYPE"
     	sh /home/deploy/$APP_NAME/tomcat/bin/startup.sh
     	echo "appName: $APP_NAME, appPort: $APP_PORT, Start-up success!"
    elif [ "$APP_TYPE" == "jar" ]; then
	 cp /home/$APP_TYPE/"$APP_NAME"."$APP_TYPE" /home/deploy/$APP_NAME/"$APP_NAME"."$APP_TYPE"
     dateTime=$(date +%Y%m%d-%H%M%S)
	 dateTimeYMD=$(date +%Y%m%d)
     set +e
     #nohup java -jar $JAVA_OPTS /home/deploy/"$APP_NAME"/"$APP_NAME"."$APP_TYPE" > /home/deploy/"$APP_NAME"/"$APP_NAME"_"$dateTime".log 2>&1 &
    nohup java -jar -Xms512m -Xmx512m /home/deploy/"$APP_NAME"/"$APP_NAME"."$APP_TYPE" \
		--spring.cloud.config.uri=http://172.16.10.170:9988 \
	    --eureka.client.service-url.defaultZone=http://172.16.10.170:7777/eureka/ \
	   >> /home/logs/"$APP_NAME"_"$dateTimeYMD".log 2>&1 &
     set -e
    fi     
}
script::initStart()
{
  echo "(1/3) 服务应用是否启动检查."
  script::installcheck
  echo "(2/3) 服务应用开始备份"
  script::backup
  echo "(3/3) 服务应用开始启动"
  script::deploy
}

main()
{
    FILE_SERVER=$1
    APP_NAME=$2
    APP_PORT=$3
    APP_TYPE=$4
    JAVA_OPTS=$5
    script::initStart
}

main $@

