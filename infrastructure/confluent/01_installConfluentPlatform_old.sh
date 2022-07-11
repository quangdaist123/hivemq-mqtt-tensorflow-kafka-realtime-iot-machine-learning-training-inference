#!/usr/bin/env bash
set -e

# set current directory of script
MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
echo $MYDIR
echo "HELLO"
echo "Deploying prometheus..."
# Make sure the tiller change is rolled out
# kubectl rollout status -n kube-system deployment tiller-deploy
# Commented next command, please do a helm repo update before executing terraform
helm repo update
kubectl create namespace monitoring || true

#helm delete prometheus -n monitoring 2>/dev/null || true
# helm install --replace --atomic prometheus --version 8.5.14 stable/prometheus-operator -n monitoring --wait
#helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
#helm repo update
#helm install --replace --atomic kube-prometheus-stack prometheus-community/kube-prometheus-stack --namespace monitoring


echo "Deploying K8s dashboard..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0-rc2/aio/deploy/recommended.yaml


kubectl create namespace operator || true
echo "Download Confluent Operator"
## check if Confluent Operator still exist
DIR="confluent-operator/"
if [[ -d "$DIR" ]]; then
  # Take action if $DIR exists. #
  echo "Operator is installed..."
  cd confluent-operator/confluent-for-kubernetes-2.3.1-20220504

else
  mkdir confluent-operator
  cd confluent-operator
  curl -O https://confluent-for-kubernetes.s3-us-west-1.amazonaws.com/confluent-for-kubernetes-2.3.1.tar.gz
  tar -xvzf confluent-for-kubernetes-2.3.1.tar.gz
  cd confluent-for-kubernetes-2.3.1-20220504
fi
#   CP 5.3
#  wget https://platform-ops-bin.s3-us-west-1.amazonaws.com/operator/confluent-operator-20190912-v0.65.1.tar.gz
#  tar -xvf confluent-operator-20190912-v0.65.1.tar.gz
#  rm confluent-operator-20190912-v0.65.1.tar.gz
#   CP 5.4
#  wget https://platform-ops-bin.s3-us-west-1.amazonaws.com/operator/confluent-operator-20200115-v0.142.1.tar.gz
#  tar -xvf confluent-operator-20200115-v0.142.1.tar.gz
#  rm confluent-operator-20200115-v0.142.1.tar.gz
#   CP 6.0
#  wget https://platform-ops-bin.s3-us-west-1.amazonaws.com/operator/confluent-operator-1.6.0-for-confluent-platform-6.0.0.tar.gz
#  tar -xvf confluent-operator-1.6.0-for-confluent-platform-6.0.0.tar.gz
#  rm confluent-operator-1.6.0-for-confluent-platform-6.0.0.tar.gz
#
#   CP 7.1.2
#  wget https://platform-ops-bin.s3-us-west-1.amazonaws.com/operator/confluent-operator-1.7.0.tar.gz
#  tar -xvzf confluent-operator-1.7.0.tar.gz
#  rm confluent-operator-1.7.0.tar.gz

#  cp ${MYDIR}/gcp.yaml helm/providers/

cd helm
helm upgrade --install confluent-operator ./confluent-for-kubernetes  --namespace operator
(set -x; cd "$(mktemp -d)" &&   OS="$(uname | tr '[:upper:]' '[:lower:]')" &&   ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&   KREW="krew-${OS}_${ARCH}" &&   curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&   tar zxvf "${KREW}.tar.gz" &&   ./"${KREW}" install krew;)
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
cd ../kubectl-plugin/
kubectl krew install   --manifest=confluent-platform.yaml   --archive=kubectl-confluent-linux-amd64.tar.gz


#cd helm/

# Install CP 5.4 cluster
#cp ${MYDIR}/operator-util.sh ../scripts
#../scripts/operator-util.sh -n operator -r co1 -f providers/gcp.yaml
#../scripts/operator-util.sh -n operator -f providers/gcp.yaml

# kubectl rollout status sts -n operator controlcenter
#kubectl get pods -n operator

# or one by one
#prepare Confluent Operator installation



# Deploy

cd ..
cd ..

DIR="confluent-kubernetes-examples/"
if [[ -d "$DIR" ]]; then
  cd confluent-kubernetes-examples
  # Take action if $DIR exists. #
#  echo "Operator is installed..."
else
  git clone https://github.com/confluentinc/confluent-kubernetes-examples.git
  cd confluent-kubernetes-examples

find ./ -type f -exec sed -i 's/namespace: operator/namespace: operator/g' {} \;
cd quickstart-deploy
kubectl apply -f ./confluent-platform.yaml -n operator
echo "Hello"
## Operator
#helm upgrade --install \
#operator \
#./confluent-operator -f \
#${MYDIR}/gcp.yaml \
#--namespace operator \
#--set operator.enabled=true
#
#
#echo "After Operator Installation: Check all pods..."
#kubectl get pods -n operator
#kubectl rollout status deployment -n operator cc-operator
#kubectl get crd | grep confluent
#
## Zookeeper
#helm upgrade --install \
#zookeeper \
#./confluent-operator -f \
#${MYDIR}/gcp.yaml \
#--namespace operator \
#--set zookeeper.enabled=true
#
#echo "After Zookeeper Installation: Check all pods..."
#kubectl get pods -n operator
#sleep 10
#kubectl rollout status sts -n operator zookeeper
#
## kafka
#helm upgrade --install \
#kafka \
#./confluent-operator -f \
#${MYDIR}/gcp.yaml \
#--namespace operator \
#--set kafka.enabled=true
#
#echo "After Kafka Broker Installation: Check all pods..."
#kubectl get pods -n operator
#sleep 10
#kubectl rollout status sts -n operator kafka
#
#
## Schema Registry
#helm upgrade --install \
#schemaregistry \
#./confluent-operator -f \
#${MYDIR}/gcp.yaml \
#--namespace operator \
#--set schemaregistry.enabled=true
#
#echo "After Schema Registry Installation: Check all pods..."
#kubectl get pods -n operator
#sleep 10
#kubectl rollout status sts -n operator schemaregistry
#
## Kafka Connect
#helm upgrade --install \
#connect \
#./confluent-operator -f \
#${MYDIR}/gcp.yaml \
#--namespace operator \
#--set connect.enabled=true
#
#echo "After Kafka Connect Installation: Check all pods..."
#kubectl get pods -n operator
#sleep 10
#kubectl rollout status sts -n operator connect
#
## ksql
#helm upgrade --install \
#ksql \
#./confluent-operator -f \
#${MYDIR}/gcp.yaml \
#--namespace operator \
#--set ksql.enabled=true
#
#echo "After KSQL Installation: Check all pods..."
#kubectl get pods -n operator
#sleep 10
#kubectl rollout status sts -n operator ksql
#
## C3
#helm upgrade --install \
#controlcenter \
#./confluent-operator -f \
#${MYDIR}/gcp.yaml \
#--namespace operator \
#--set controlcenter.enabled=true
#
#echo "After Control Center Installation: Check all pods..."
#kubectl get pods -n operator
#sleep 10
#kubectl rollout status sts -n operator controlcenter
#
#echo " Loadbalancers are created please wait a couple of minutes..."
#sleep 60
#kubectl get services -n operator | grep LoadBalancer
#echo " After all external IP Adresses are seen, add your local /etc/hosts via "
#echo "sudo /etc/hosts"
#echo "EXTERNAL-IP  ksql.mydevplatform.gcp.cloud ksql-bootstrap-lb ksql"
#echo "EXTERNAL-IP  schemaregistry.mydevplatform.gcp.cloud schemaregistry-bootstrap-lb schemaregistry"
#echo "EXTERNAL-IP  controlcenter.mydevplatform.gcp.cloud controlcenter controlcenter-bootstrap-lb"
#echo "EXTERNAL-IP  b0.mydevplatform.gcp.cloud kafka-0-lb kafka-0 b0"
#echo "EXTERNAL-IP  b1.mydevplatform.gcp.cloud kafka-1-lb kafka-1 b1"
#echo "EXTERNAL-IP  b2.mydevplatform.gcp.cloud kafka-2-lb kafka-2 b2"
#echo "EXTERNAL-IP  kafka.mydevplatform.gcp.cloud kafka-bootstrap-lb kafka"
#kubectl get services -n operator | grep LoadBalancer
#sleep 10
#
#echo "After Load balancer Deployments: Check all Confluent Services..."
#kubectl get services -n operator
#kubectl get pods -n operator
#echo "Confluent Platform into GKE cluster is finished."

echo "Create Topics on Confluent Platform for Test Generator"
# Create Kafka Property file in all pods
kubectl rollout status sts -n operator kafka
echo "deploy kafka.property file into all brokers"
kubectl -n operator exec -it kafka-0 -- bash -c "printf \"bootstrap.servers=kafka:9071\nsasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username=\"test\" password=\"test123\";\nsasl.mechanism=PLAIN\nsecurity.protocol=SASL_PLAINTEXT\" > /opt/kafka.properties"
kubectl -n operator exec -it kafka-1 -- bash -c "printf \"bootstrap.servers=kafka:9071\nsasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username=\"test\" password=\"test123\";\nsasl.mechanism=PLAIN\nsecurity.protocol=SASL_PLAINTEXT\" > /opt/kafka.properties"
kubectl -n operator exec -it kafka-2 -- bash -c "printf \"bootstrap.servers=kafka:9071\nsasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username=\"test\" password=\"test123\";\nsasl.mechanism=PLAIN\nsecurity.protocol=SASL_PLAINTEXT\" > /opt/kafka.properties"

## Create Topic sensor-data
#echo "Create Topic sensor-data"
## Topic might exist already, make idempotent by ignoring errors here
#kubectl -n operator exec -it kafka-0 -- bash -c "kafka-topics --bootstrap-server kafka:9071 --command-config kafka.properties --create --topic sensor-data --replication-factor 3 --partitions 10 --config retention.ms=100000" || true
#echo "Create Topic model-predictions"
## Topic might exist already, make idempotent by ignoring errors here
#kubectl -n operator exec -it kafka-0 -- bash -c "kafka-topics --bootstrap-server kafka:9071 --command-config kafka.properties --create --topic model-predictions --replication-factor 3 --partitions 10 --config retention.ms=100000" || true
## list Topics
#kubectl -n operator exec -it kafka-0 -- bash -c "kafka-topics --bootstrap-server kafka:9071 --list --command-config kafka.properties"
#
#kubectl -n operator exec -it ksql-0 -- bash -c "curl -X \"POST\" \"http://ksql:8088/ksql\" \
#     -H \"Content-Type: application/vnd.ksql.v1+json; charset=utf-8\" \
#     -d $'{
#  \"ksql\": \"TERMINATE QUERY CTAS_SENSOR_DATA_EVENTS_PER_5MIN_T_2;\",
#  \"streamsProperties\": {}
#}'" || true
#kubectl -n operator exec -it ksql-0 -- bash -c "curl -X \"POST\" \"http://ksql:8088/ksql\" \
#     -H \"Content-Type: application/vnd.ksql.v1+json; charset=utf-8\" \
#     -d $'{
#  \"ksql\": \"DROP TABLE IF EXISTS SENSOR_DATA_EVENTS_PER_5MIN_T;\",
#  \"streamsProperties\": {}
#}'"
#kubectl -n operator exec -it ksql-0 -- bash -c "curl -X \"POST\" \"http://ksql:8088/ksql\" \
#     -H \"Content-Type: application/vnd.ksql.v1+json; charset=utf-8\" \
#     -d $'{
#  \"ksql\": \"TERMINATE QUERY CSAS_SENSOR_DATA_S_AVRO_REKEY_1;\",
#  \"streamsProperties\": {}
#}'" || true
#kubectl -n operator exec -it ksql-0 -- bash -c "curl -X \"POST\" \"http://ksql:8088/ksql\" \
#     -H \"Content-Type: application/vnd.ksql.v1+json; charset=utf-8\" \
#     -d $'{
#  \"ksql\": \"DROP STREAM IF EXISTS SENSOR_DATA_S_AVRO_REKEY;\",
#  \"streamsProperties\": {}
#}'"
#kubectl -n operator exec -it ksql-0 -- bash -c "curl -X \"POST\" \"http://ksql:8088/ksql\" \
#     -H \"Content-Type: application/vnd.ksql.v1+json; charset=utf-8\" \
#     -d $'{
#  \"ksql\": \"TERMINATE QUERY CSAS_SENSOR_DATA_S_AVRO_0;\",
#  \"streamsProperties\": {}
#}'" || true
#kubectl -n operator exec -it ksql-0 -- bash -c "curl -X \"POST\" \"http://ksql:8088/ksql\" \
#     -H \"Content-Type: application/vnd.ksql.v1+json; charset=utf-8\" \
#     -d $'{
#  \"ksql\": \"DROP STREAM IF EXISTS SENSOR_DATA_S_AVRO;\",
#  \"streamsProperties\": {}
#}'"
#kubectl -n operator exec -it ksql-0 -- bash -c "curl -X \"POST\" \"http://ksql:8088/ksql\" \
#     -H \"Content-Type: application/vnd.ksql.v1+json; charset=utf-8\" \
#     -d $'{
#  \"ksql\": \"DROP STREAM IF EXISTS SENSOR_DATA_S;\",
#  \"streamsProperties\": {}
#}'"
## Create STREAMS
## CURL CREATE
#echo "CREATE STREAM SENSOR_DATA_S"
#kubectl -n operator exec -it ksql-0 -- bash -c "curl -X \"POST\" \"http://ksql:8088/ksql\" \
#     -H \"Content-Type: application/vnd.ksql.v1+json; charset=utf-8\" \
#     -d $'{
#  \"ksql\": \"CREATE STREAM SENSOR_DATA_S (coolant_temp DOUBLE, intake_air_temp DOUBLE, intake_air_flow_speed DOUBLE, battery_percentage DOUBLE, battery_voltage DOUBLE, current_draw DOUBLE, speed DOUBLE, engine_vibration_amplitude DOUBLE, throttle_pos DOUBLE, tire_pressure11 INT, tire_pressure12 INT, tire_pressure21 INT, tire_pressure22 INT, accelerometer11_value DOUBLE, accelerometer12_value DOUBLE, accelerometer21_value DOUBLE, accelerometer22_value DOUBLE, control_unit_firmware INT, failure_occurred STRING) WITH (kafka_topic=\'sensor-data\', value_format=\'JSON\');\",
#  \"streamsProperties\": {}
#}'"
#echo "CREATE STREAM SENSOR_DATA_S_AVRO"
#kubectl -n operator exec -it ksql-0 -- bash -c "curl -X \"POST\" \"http://ksql:8088/ksql\" \
#     -H \"Content-Type: application/vnd.ksql.v1+json; charset=utf-8\" \
#     -d $'{
#  \"ksql\": \"CREATE STREAM SENSOR_DATA_S_AVRO WITH (VALUE_FORMAT=\'AVRO\') AS SELECT * FROM SENSOR_DATA_S;\",
#  \"streamsProperties\": {}
#}'"
#echo "CREATE STREAM SENSOR_DATA_S_AVRO_REKEY"
#kubectl -n operator exec -it ksql-0 -- bash -c "curl -X \"POST\" \"http://ksql:8088/ksql\" \
#     -H \"Content-Type: application/vnd.ksql.v1+json; charset=utf-8\" \
#     -d $'{
#  \"ksql\": \"CREATE STREAM SENSOR_DATA_S_AVRO_REKEY AS SELECT ROWKEY as CAR, * FROM SENSOR_DATA_S_AVRO PARTITION BY CAR;\",
#  \"streamsProperties\": {}
#}'"
#echo "CREATE TABLE SENSOR_DATA_EVENTS_PER_5MIN_T"
#kubectl -n operator exec -it ksql-0 -- bash -c "curl -X \"POST\" \"http://ksql:8088/ksql\" \
#     -H \"Content-Type: application/vnd.ksql.v1+json; charset=utf-8\" \
#     -d $'{
#  \"ksql\": \"CREATE TABLE SENSOR_DATA_EVENTS_PER_5MIN_T AS SELECT car, count(*) as event_count FROM SENSOR_DATA_S_AVRO_REKEY WINDOW TUMBLING (SIZE 5 MINUTE) GROUP BY car;\",
#  \"streamsProperties\": {}
#}'"
echo "####################################"
echo "## Confluent Deployment finshed ####"
echo "####################################"