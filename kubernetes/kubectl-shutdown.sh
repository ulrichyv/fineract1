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

# Fonction pour supprimer une ressource avec vérification
delete_resource() {
    local type=$1
    local name=$2
    echo "Suppression de $type $name..."
    if kubectl get $type $name > /dev/null 2>&1; then
        kubectl delete $type $name
    else
        echo "$type $name non trouvé, ignoré"
    fi
}

echo "Arrêt de l'environnement Fineract..."

# Suppression des déploiements
delete_resource deployment fineract-server
delete_resource deployment fineractmysql
delete_resource deployment mifoscommunity

# Suppression des services
delete_resource service fineract-server
delete_resource service fineractmysql

# Suppression des ressources persistantes
delete_resource pvc fineractmysql-pv-claim
delete_resource pv fineractmysql-pv-volume

# Suppression des configurations
delete_resource secret fineract-tenants-db-secret
delete_resource configmap fineractmysql-initdb

echo "Nettoyage des pods terminés..."
kubectl delete pods --field-selector=status.phase=Succeeded > /dev/null 2>&1

echo "Vérification des ressources restantes..."
echo "Pods:"
kubectl get pods -l 'app in (fineract-server,mifoscommunity)'
echo
echo "Services:"
kubectl get svc -l 'app in (fineract-server,mifoscommunity)'
echo
echo "PVC/PV:"
kubectl get pvc,pv | grep fineract

echo
echo "Environnement Fineract arrêté avec succès."