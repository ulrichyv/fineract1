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
#!/bin/bash

# Generate random password
DB_PASSWORD=$(head /dev/urandom | LC_CTYPE=C tr -dc 'A-Za-z0-9' | head -c 16)

# Create secrets
kubectl create secret generic fineract-tenants-db-secret \
  --from-literal=username=fineract \
  --from-literal=password=$DB_PASSWORD \
  --dry-run=client -o yaml | kubectl apply -f -

# Deploy MySQL
echo "Deploying MySQL..."
kubectl apply -f fineract-mysql-deployment.yml

# Wait for MySQL
echo "Waiting for MySQL to be ready..."
kubectl wait --for=condition=ready pod -l tier=fineractmysql --timeout=300s

# Initialize database
echo "Initializing database..."
kubectl exec -it $(kubectl get pods -l tier=fineractmysql -o jsonpath='{.items[0].metadata.name}') -- \
  mysql -uroot -p$DB_PASSWORD -e "CREATE DATABASE IF NOT EXISTS fineract_tenants; GRANT ALL PRIVILEGES ON fineract_tenants.* TO 'fineract'@'%'; FLUSH PRIVILEGES;"

# Deploy Fineract
echo "Deploying Fineract Server..."
kubectl apply -f fineract-server-deployment.yml
kubectl apply -f fineract-server-service.yml

# Wait for Fineract
echo "Waiting for Fineract to be ready..."
kubectl wait --for=condition=ready pod -l tier=backend --timeout=300s

# Get access information
echo ""
echo "Deployment completed successfully!"
echo "Database credentials:"
echo "Username: fineract"
echo "Password: $DB_PASSWORD"
echo ""
echo "Fineract Server URL: https://$(kubectl get svc fineract-server -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):8443"

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