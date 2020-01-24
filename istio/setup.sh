#!/usr/bin/env bash

set -e

deploy_env=${1}


#curl -L https://istio.io/downloadIstio | sh -
brew install istioctl
#cd istio-1.4.3/
istioctl manifest apply --set profile=demo
kubectl label namespace default istio-injection=enabled
kubectl apply -f bookinfo.yaml
kubectl apply -f bookinfo-gateway.yaml
kubectl apply -f destination-rule-all.yaml

if [ $deploy_env = "eks" ]; then
    export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')
    export SECURE_INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].port}')
fi

if [ $deploy_env = "dockerdesktop" ]; then
    export INGRESS_PORT=80
    export SECURE_INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
    export INGRESS_HOST=127.0.0.1

fi

export GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT

echo "${GATEWAY_URL}"

echo "Attempting test until it works..."

until $(curl --output /dev/null --silent --head --fail http://${GATEWAY_URL}/productpage); do
    printf '.'
    sleep 5
done

curl -s http://${GATEWAY_URL}/productpage | grep -o "<title>.*</title>"

# Launch the Kiali Dashboard
istioctl dashboard kiali &
while true; do curl -s http://127.0.0.1/productpage | grep -o "<title>.*</title>"; done