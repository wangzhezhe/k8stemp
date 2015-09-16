#!/bin/bash

set -x

if [[ -z $1 ]];then
	echo "Need a param which specifies where app data was mounted. Exit."
	exit 1
fi
# tear down alive resources
./kubectl delete rc --all
./kubectl delete pods --all
./kubectl delete svc --all 

sudo rm -rf /var/lib/etcd*
sudo rm -rf $1/docker 

sudo rm -rf ./cert
sudo rm -rf ./tarpackage

# kill docker bootstrap
docker_bootstrap_pid=$(ps -ef | grep docker-bootstrap | grep -v grep | awk '{print $2}')
if [[ -z "$docker_bootstrap_pid" ]]; then
	echo "docker bootstrap deamon not up"
else
	docker_bootstrap_container=$(docker -H unix:///var/run/docker-bootstrap.sock ps -a -q)
	if [[ -z "$docker_bootstrap_container" ]]; then
		echo "no running bootstrap container"
	else
		sudo docker -H unix:///var/run/docker-bootstrap.sock rm -f $(docker -H unix:///var/run/docker-bootstrap.sock ps -a -q) 2> /dev/null
	fi

	docker_bootstrap_images=$(docker -H unix:///var/run/docker-bootstrap.sock images -q)
	if [[ -z "$docker_bootstrap_images" ]]; then
		echo "no existing bootstrap images"
	else
		#echo "dont clean up bootstrap images"
		sudo docker -H unix:///var/run/docker-bootstrap.sock rmi -f $(docker -H unix:///var/run/docker-bootstrap.sock images -q) 2> /dev/null
	fi

	sudo kill -9 $docker_bootstrap_pid 2> /dev/null
fi


# kill docker
docker_pid=$(ps -ef | grep docker | grep -v grep | awk '{print $2}')
if [[ -z "$docker_pid" ]]; then
	echo "docker deamon not up"
else
	docker_container=$(docker ps -a -q)
	if [[ -z "$docker_container" ]]; then
		echo "no running container"
	else
		sudo docker rm -f $(docker ps -a -q) 2> /dev/null
	fi

	docker_image=$(docker images -q)
	if [[ -z "$docker_image" ]]; then
		echo "no existing images"
	else
		echo "do not clean up images"
		#sudo docker rmi -f $(docker images -q) 2> /dev/null
	fi
	sudo kill -9 $docker_pid 2> /dev/null
fi

#hyperkube
hyperkube_pid=$(pgrep hyperkube)
if [[ -z "$hyperkube_pid" ]]; then
	echo "hyperkube not exist"
else
	sudo kill -9 $hyperkube_pid 2> /dev/null
fi

# clean etcd port
etcd_pid=$(pgrep etcd)
if [[ -z "$etcd_pid" ]]; then
	echo "etcd not exist"
else
	sudo kill -9 $etcd_pid 2> /dev/null
fi


#clean flannel port
flannel_pid=$(pgrep flanneld)
if [[ -z "$flannel_pid" ]]; then
	echo "flannel not exist"
else
	sudo kill -9 $flannel_pid 2> /dev/null
fi

# clean cadvisor port
cadvisor_pid=$(pgrep cadvisor)
if [[ -z "$cadvisor_pid" ]]; then
	echo "cadvisor not exist"
else
	sudo kill -9 $cadvisor_pid 2> /dev/null
fi

# gorouter port 
gorouter_pid=$(pgrep gorouter)
if [[ -z "$gorouter_pid" ]]; then
	echo "gorouter not exist"
else
	sudo kill -9 $gorouter_pid 2> /dev/null
fi

# logserver port 
logserver_pid=$(pgrep Server)
if [[ -z "$logserver_pid" ]]; then
	echo "logserver not exist"
else
	sudo kill -9 $logserver_pid 2> /dev/null
fi

# monitserver port
monitserver_pid=$(pgrep monit-server)
if [[ -z "$monitserver_pid" ]]; then
	echo "monitserver not exist"
else
	sudo kill -9 $monitserver_pid 2> /dev/null
fi

# registry port 
registry_pid=$(pgrep registry)
if [[ -z "$registry_pid" ]]; then
	echo "registry not exist"
else
	sudo kill -9 $registry_pid 2> /dev/null
fi


lsb_dist="$(lsb_release -si)"
	
lsb_dist="$(echo "$lsb_dist" | tr '[:upper:]' '[:lower:]')"

case "$lsb_dist" in
	fedora|centos)
        sudo systemctl stop docker
        sudo rm -rf /etc/sysconfig/docker 2> /dev/null
    ;;
    ubuntu|debian|linuxmint)
        sudo service docker stop
        sudo rm -rf /etc/default/docker 2> /dev/null
    ;;
esac


if [[ -d "/var/lib/docker-bootstrap" ]]; then
	sudo umount $(mount | grep /var/lib/docker-bootstrap | awk '{print $1}')
fi

if grep '/dev/mapper/docker-*' /etc/mtab > /dev/null 2>&1; then
	for dm in /dev/mapper/docker-*; do 
		umount $dm; 
		dmsetup remove $dm; 
	done 
fi
 
#sudo umount /var/lib/docker 2> /dev/null 
#sudo rm -rf /var/lib/docker 2> /dev/null

sudo umount /var/lib/kubelet 2> /dev/null
sudo rm -rf /var/lib/kubelet 2> /dev/null

sudo rm -rf /var/run/docker.sock 2> /dev/null
sudo rm -rf /var/lib/docker-bootstrap 2> /dev/null

case "$lsb_dist" in
	fedora|centos)
        sudo systemctl start docker
        
    ;;
    ubuntu|debian|linuxmint)
        sudo service docker start
        
    ;;
esac

# kill docker
docker_pid=$(ps -ef | grep docker | grep -v grep | awk '{print $2}')
if [[ -z "$docker_pid" ]]; then
	echo "docker deamon not up"
else
	docker_container=$(docker ps -a -q)
	if [[ -z "$docker_container" ]]; then
		echo "no running container"
	else
		sudo docker rm -f $(docker ps -a -q) 2> /dev/null
	fi

	docker_image=$(docker images -q)
	if [[ -z "$docker_image" ]]; then
		echo "no existing images"
	else
		echo "do not clean up images"
		#sudo docker rmi -f $(docker images -q) 2> /dev/null
	fi
fi