#!/bin/bash
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements. See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership. The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License. You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied. See the License for the
# specific language governing permissions and limitations
# under the License.
#

# Fonction pour attendre qu'un pod soit en état Running
wait_for_pod() {
    local selector=$1
    local pod=""
    local status=""
    
    echo -n "Waiting for pod with selector $selector to be created..."
    while [[ -z "$pod" ]]; do
        pod=$(kubectl get pods -l "$selector" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        sleep 2
    done
    echo " found: $pod"
    
    echo -n "Waiting for pod $pod to be Running..."
    while [[ "$status" != "Running" ]]; do
        status=$(kubectl get pod "$pod" -o jsonpath='{.status.phase}')
        if [[ "$status" == "Failed" || "$status" == "Error" ]]; then
            echo "Pod failed to start"
            kubectl logs "$pod"
            exit 1
        fi
        sleep 2
    done
    echo " running"
    
    # Attendre que le pod soit vraiment prêt
    echo -n "Waiting for pod $pod to be fully ready..."
    kubectl wait --for=condition=ready pod/"$pod" --timeout=300s
    echo " ready"
}

# Génération du mot de passe
DB_PASSWORD=$(head /dev/urandom | LC_CTYPE=C tr -dc 'A-Za-z0-9' | head -c 16)

echo "Setting Up Fineract service configuration..."
kubectl create secret generic fineract-tenants-db-secret \
  --from-literal=username=root \
  --from-literal=password="$DB_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f fineractmysql-configmap.yml

echo
echo "Starting fineractmysql..."
kubectl apply -f fineractmysql-deployment.yml
wait_for_pod "tier=fineractmysql"

# Initialisation supplémentaire pour la base de données
echo "Initializing database..."
kubectl exec -it "$(kubectl get pods -l tier=fineractmysql -o jsonpath='{.items[0].metadata.name}')" -- \
  mysql -uroot -p"$DB_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS fineract_tenants;"

echo
echo "Starting fineract server..."
kubectl apply -f fineract-server-deployment.yml
wait_for_pod "tier=backend"

echo "Fineract server is up and running"

echo "Starting Mifos Community UI..."
kubectl apply -f fineract-mifoscommunity-deployment.yml
wait_for_pod "app=mifoscommunity"

echo "Mifos Community UI is up and running"

# Affichage des informations d'accès
echo
echo "Deployment completed successfully!"
echo "Database password: $DB_PASSWORD"
echo "You can access Fineract at: $(kubectl get service fineract-server -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):8443"
echo "You can access Mifos Community UI at: $(kubectl get service mifoscommunity -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"