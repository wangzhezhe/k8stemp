set -x

	start_k8s(){
	#add basic info
    source ./assignimage.sh
	#./assignimage.sh
	#create ca file
	source ./createca.sh
	
	lsb_dist="$(lsb_release -si)"
	
	lsb_dist="$(echo "$lsb_dist" | tr '[:upper:]' '[:lower:]')"

    case "$lsb_dist" in
		fedora|centos)
            DOCKER_CONF="/etc/sysconfig/docker"
        ;;
        ubuntu|debian|linuxmint)
            DOCKER_CONF="/etc/default/docker"
        ;;
    esac
	
	case "$lsb_dist" in
		fedora|centos)
            yum install tar -y
        ;;
        ubuntu|debian|linuxmint)
            apt-get install tar -y
        ;;
    esac
	
    LOCAL_PATH=$(pwd)
	# sudo docker -d -H unix:///var/run/docker-bootstrap.sock -p /var/run/docker-bootstrap.pid --iptables=false --ip-masq=false --bridge=none --graph=/var/lib/docker-bootstrap 2> /var/log/docker-bootstrap.log 1> /dev/null
	sudo -b docker -d -H unix:///var/run/docker-bootstrap.sock -p /var/run/docker-bootstrap.pid --iptables=false --ip-masq=false --graph=/var/lib/docker-bootstrap 2> /var/log/docker-bootstrap.log 1> /dev/null
	
	sleep 2
	docker -H unix:///var/run/docker-bootstrap.sock pull ${ETCD_IMAGE}
    docker -H unix:///var/run/docker-bootstrap.sock pull ${FLANNEL_IMAGE}
    docker -H unix:///var/run/docker-bootstrap.sock pull ${HYPERKUBE_IMAGE}
    docker -H unix:///var/run/docker-bootstrap.sock pull ${APISERVER_IMAGE}

	
	# Start etcd infra0
	docker -H unix:///var/run/docker-bootstrap.sock run \
--restart=on-failure:10 --net=host -d -v /var/lib/etcd0:/var/etcd/data/ --name=infra0 \
${ETCD_IMAGE} //usr/local/bin/etcd \
--name=infra0 \
--initial-advertise-peer-urls=http://${PRIVATE_IP}:2380 \
--listen-peer-urls=http://${PRIVATE_IP}:2380 --listen-client-urls="http://${PRIVATE_IP}:2379,http://127.0.0.1:2379" \
--advertise-client-urls=http://${PRIVATE_IP}:2379 \
--initial-cluster-token=etcd-cluster-1 \
--initial-cluster="infra0=http://${PRIVATE_IP}:2380,infra1=http://${PRIVATE_IP}:10001,infra2=http://${PRIVATE_IP}:10003" \
--initial-cluster-state=new \
--data-dir=/var/etcd/data
	
	#Start etcd infra1
	docker -H unix:///var/run/docker-bootstrap.sock run \
--restart=on-failure:10 --net=host -d -v /var/lib/etcd1:/var/etcd/data/ --name=infra1 \
${ETCD_IMAGE} //usr/local/bin/etcd \
--name=infra1 \
--initial-advertise-peer-urls=http://${PRIVATE_IP}:10001 \
--listen-peer-urls=http://${PRIVATE_IP}:10001 --listen-client-urls="http://${PRIVATE_IP}:10002,http://127.0.0.1:10002" \
--advertise-client-urls=http://${PRIVATE_IP}:10002 \
--initial-cluster-token=etcd-cluster-1 \
--initial-cluster="infra0=http://${PRIVATE_IP}:2380,infra1=http://${PRIVATE_IP}:10001,infra2=http://${PRIVATE_IP}:10003" \
--initial-cluster-state=new \
--data-dir=/var/etcd/data

	#Start etcd infra2
	docker -H unix:///var/run/docker-bootstrap.sock run \
--restart=on-failure:10 --net=host -d -v /var/lib/etcd2:/var/etcd/data/ --name=infra2 \
${ETCD_IMAGE} //usr/local/bin/etcd \
--name=infra2 \
--initial-advertise-peer-urls=http://${PRIVATE_IP}:10003 \
--listen-peer-urls=http://${PRIVATE_IP}:10003 --listen-client-urls="http://${PRIVATE_IP}:10004,http://127.0.0.1:10004" \
--advertise-client-urls=http://${PRIVATE_IP}:10004 \
--initial-cluster-token=etcd-cluster-1 \
--initial-cluster="infra0=http://${PRIVATE_IP}:2380,infra1=http://${PRIVATE_IP}:10001,infra2=http://${PRIVATE_IP}:10003" \
--initial-cluster-state=new \
--data-dir=/var/etcd/data

	sleep 10
	# Set flannel net config
	docker -H unix:///var/run/docker-bootstrap.sock run --net=host ${ETCD_IMAGE} /usr/local/bin/etcdctl --peers="http://${PRIVATE_IP}:2379,http://${PRIVATE_IP}:10002,http://${PRIVATE_IP}:10004" \
set /coreos.com/network/config '{ "Network": "10.1.0.0/16" }'
	# iface may change to a private network interface, eth0 is for ali ecs
	sleep 10
	flannelCID=$(docker -H unix:///var/run/docker-bootstrap.sock run \
-d --net=host --privileged -v /dev/net:/dev/net ${FLANNEL_IMAGE} /opt/bin/flanneld \
-iface=${IFACE} --etcd-endpoints=http://${PRIVATE_IP}:2379,http://${PRIVATE_IP}:10002,http://${PRIVATE_IP}:10004)
	sleep 10
	# Configure docker net settings and registry setting and restart it
	#docker -H unix:///var/run/docker-bootstrap.sock cp ${flannelCID}:/run/flannel/subnet.env .
	docker -H unix:///var/run/docker-bootstrap.sock exec ${flannelCID} cat /run/flannel/subnet.env > subnet.env
	source subnet.env
	
	case "$lsb_dist" in
		fedora|centos)
            echo "OPTIONS=\"-H=unix:///var/run/docker.sock -H tcp://0.0.0.0:2376 --mtu=${FLANNEL_MTU} --bip=${FLANNEL_SUBNET} --insecure-registry=${USER}reg:${PRIVATE_PORT}\"" | tee ${DOCKER_CONF}
            yum install -y net-tools
        ;;
        ubuntu|debian|linuxmint)
            echo "DOCKER_OPTS=\"-H=unix:///var/run/docker.sock -H tcp://0.0.0.0:2376 --mtu=${FLANNEL_MTU} --bip=${FLANNEL_SUBNET} --insecure-registry=${USER}reg:${PRIVATE_PORT}\"" | tee ${DOCKER_CONF}
	
        ;;
    esac

	ifconfig docker0 down
	
	
	case "$lsb_dist" in
		fedora|centos)
            yum install -y bridge-utils && brctl delbr docker0 && systemctl restart docker
        ;;
        ubuntu|debian|linuxmint)
            apt-get install -y bridge-utils && brctl delbr docker0 && service docker restart
        ;;
    esac
	
	
	sleep 5
	docker run --restart=always -d -p 5000:5000 -v ${HOSTDIR}:/tmp/registry-dev --name registry k8szju/registry:2.1.1
	
	if grep -Fxq "${PRIVATE_IP} ${USER}reg" /etc/hosts
	then
	echo "modify /etc/hosts"
	else
	echo "${PRIVATE_IP} ${USER}reg" | tee -a /etc/hosts
	fi
	
	#install gorouter
	#docker run --net=host --restart=always -d liuyilun/gorouter:latest
	#start api server (attention to the certpath)
	
	sleep 10
	
	# use self-signed ca
	docker -H unix:///var/run/docker-bootstrap.sock run -id --restart=always --net=host \
-v ${LOCAL_PATH}/cert:/cert/ k8szju/apiserver:1.0.5 /apiserver \
--insecure-bind-address=${PRIVATE_IP} --insecure-port=8080 \
--bind-address=0.0.0.0 --secure-port=8081 \
--etcd_servers=http://${PRIVATE_IP}:2379,http://${PRIVATE_IP}:10002,http://${PRIVATE_IP}:10004 \
--logtostderr=true --service-cluster-ip-range=192.168.3.0/24 \
--token_auth_file=/cert/tokens.csv --client_ca_file=/cert/ca.crt \
--tls-private-key-file=/cert/server.key --tls-cert-file=/cert/server.crt
	
	sleep 5
	
	# Start Master components (two add start policy) attention dns config dns ip could be assigned manually	
	rm ./image/master-two.json
	cp ./image/master-two-template.json ./image/master-two.json
	sed -i "s/PRIVATEIP/${PRIVATE_IP}/g" ./image/master-two.json
	#sed -i "s/HYPERKUBE_IMAGE/${HYPERKUBE_IMAGE}/g" ./image/master-two.json

	
	sleep 5
	docker -H unix:///var/run/docker-bootstrap.sock run --net=host -d -v /var/run/docker.sock:/var/run/docker.sock  -v ${LOCAL_PATH}/image/hyper/master-two.json:/etc/kubernetes/manifests-two/master.json  ${HYPERKUBE_IMAGE} /hyperkube kubelet --api_servers=http://${PRIVATE_IP}:8080 --v=2 --address=${PRIVATE_IP} --enable_server --hostname_override=${PRIVATE_IP} --config=/etc/kubernetes/manifests-two --cluster_dns=192.168.3.10 --cluster_domain=cluster.local
	sleep 5
	docker -H unix:///var/run/docker-bootstrap.sock run -d --net=host --privileged ${HYPERKUBE_IMAGE} /hyperkube proxy --master=http://${PRIVATE_IP}:8080 --v=2
	sleep 5

	# Start Monitor

	docker run -d \
--volume=/:/rootfs:ro \
--volume=/var/run:/var/run:rw \
--volume=/sys:/sys:ro \
--volume=/var/lib/docker/:/var/lib/docker:ro \
--publish=4194:8080 \
--detach=true \
--restart=always \
google/cadvisor:latest

sleep 5

     #docker run --privileged=true --net=host --restart=always -d -v '/etc/ssl/certs:/etc/ssl/certs' monitserver:latest
      
	 echo "Monitserver installation ok"
	  
	 #add packetbeat
     
	 #sleep 2
	 
	 #docker run -d --net=host --volume=${HOSTDIR}:/root logserver:v1 ${PRIVATE_IP} ${DAY}

	 #docker run -d --net=host --volume=/var/lib/docker/containers:/var/lib/docker/containers logstash-forwarder:v1 ${PRIVATE_IP}
	 # modify the base images
	 #docker tag appbase:v4 ${USER}reg:5000/apm-jre7-tomcat7:v4
	 #docker push ${USER}reg:5000/apm-jre7-tomcat7:v4

	 # install logstash
	 
	 
	}
	start_k8s