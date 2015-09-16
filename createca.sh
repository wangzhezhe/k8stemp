#!/bin/bash

	mkdir -p ./cert
	
	cd ./cert
	
	rm ../openssl.conf
	cp ../openssl_template.conf ../openssl.conf
	sed -i "s/PUBLIC_IP/${PRIVATE_IP}/g" ../openssl.conf
	
	openssl genrsa -out ca.key 2048

    openssl req -x509 -new -nodes -key ca.key -subj "/CN=zju.com" -days 5000 -out ca.crt

    openssl genrsa -out server.key 2048
	
	sed -i "s/PUBLIC_IP/${PUBLIC_IP}/g" ./openssl.conf
	
    openssl req -new -key server.key -subj "/CN=${CLUSTER}.${USER}" -config ../openssl.conf -out server.csr

    #openssl x509 -req -days 3650 -in server.csr -signkey server.key -out server.crt -extensions v3_req -extfile ../openssl.conf
	
	openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 5000 -extensions v3_req -extfile ../openssl.conf
	
	touch tokens.csv
	
	echo "abcdTOKEN1234,zju,zju" > tokens.csv
	
	cd ..