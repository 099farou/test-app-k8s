# Tests Avancés et Scénarios GitOps

## 🧪 1. Tests de Résilience

### 1.1 Test de redémarrage de pod

```bash
# Supprimer un pod et vérifier qu'il redémarre automatiquement
kubectl delete pod -n dev -l app=demo-app --force --grace-period=0

# Observer la recréation
kubectl get pods -n dev -w

# ArgoCD détecte-t-il une dérive ? Non, car le Deployment gère les replicas
```

### 1.2 Test de modification manuelle (drift detection)

```bash
# Modifier manuellement le nombre de replicas
kubectl scale deployment -n dev dev-demo-app --replicas=5

# Observer ArgoCD détecter et corriger (si selfHeal: true)
# Dans l'UI ArgoCD, vous verrez "OutOfSync" puis "Synced" automatiquement

# Vérifier les events ArgoCD
kubectl get events -n argocd | grep demo-app-dev
```

### 1.3 Test de suppression de ressource

```bash
# Supprimer le service manuellement
kubectl delete service -n dev dev-demo-app

# Avec prune: true et selfHeal: true, ArgoCD le recrée automatiquement
# Vérifier après quelques secondes
kubectl get service -n dev dev-demo-app
```

## 🔄 2. Tests de Déploiement GitOps

### 2.1 Modification simple (ConfigMap)

```bash
# Modifier le fichier HTML
cd test-app-k8s
vim base/configmap.yaml
# Changez le titre, par exemple

git add base/configmap.yaml
git commit -m "test: changement de titre"
git push

# ArgoCD détecte le changement (max 3 minutes)
# Observer dans l'UI ou:
argocd app get demo-app-dev

# Pour voir le changement immédiatement:
kubectl rollout restart deployment -n dev dev-demo-app
```

### 2.2 Changement d'image

```bash
# Modifier l'image nginx
vim base/deployment.yaml
# Changez nginx:1.25-alpine en nginx:1.26-alpine

git add base/deployment.yaml
git commit -m "feat: mise à jour nginx 1.26"
git push

# Observer le rolling update
kubectl rollout status deployment -n dev dev-demo-app
kubectl get pods -n dev -w
```

### 2.3 Ajout d'une ressource

```bash
# Créer un HorizontalPodAutoscaler
cat > base/hpa.yaml <<EOF
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: demo-app
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: demo-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
EOF

# Ajouter à kustomization.yaml
vim base/kustomization.yaml
# Ajoutez "- hpa.yaml" dans resources

git add base/hpa.yaml base/kustomization.yaml
git commit -m "feat: ajout HPA"
git push

# Vérifier que ArgoCD déploie le HPA
kubectl get hpa -n dev
```

## 🎯 3. Tests de Réseau

### 3.1 Test d'accessibilité interne

```bash
# Créer un pod de test dans le même namespace
kubectl run test-internal -n dev --rm -it --image=busybox --restart=Never -- sh

# Dans le pod:
wget -O- http://dev-demo-app
wget -O- http://dev-demo-app.dev.svc.cluster.local

# Tester la résolution DNS
nslookup dev-demo-app.dev.svc.cluster.local
```

### 3.2 Test d'accessibilité externe (Ingress)

```bash
# Test HTTP basique
curl -v http://demo-app-dev.example.com

# Test avec headers
curl -H "Host: demo-app-dev.example.com" http://<IP_INGRESS>

# Test avec resolution DNS locale
curl --resolve demo-app-dev.example.com:80:<IP_INGRESS> http://demo-app-dev.example.com
```

### 3.3 Test de connectivité pod-to-pod

```bash
# Récupérer l'IP d'un pod
POD_IP=$(kubectl get pod -n dev -l app=demo-app -o jsonpath='{.items[0].status.podIP}')

# Tester depuis un autre pod
kubectl run test-pod -n dev --rm -it --image=busybox --restart=Never -- wget -O- http://$POD_IP
```

## 📊 4. Tests de Charge

### 4.1 Test avec Apache Bench

```bash
# Installer ab si nécessaire
# sudo apt-get install apache2-utils

# Test simple (100 requêtes, 10 concurrent)
ab -n 100 -c 10 http://demo-app-dev.example.com/

# Test de charge (10000 requêtes, 100 concurrent)
ab -n 10000 -c 100 http://demo-app-dev.example.com/

# Observer les pods pendant le test
kubectl top pods -n dev
kubectl get hpa -n dev -w
```

### 4.2 Test avec Hey

```bash
# Installer hey
go install github.com/rakyll/hey@latest

# Test de charge
hey -z 30s -c 50 http://demo-app-dev.example.com/

# Observer l'autoscaling (si HPA configuré)
kubectl get hpa -n dev -w
```

## 🔐 5. Tests de Sécurité

### 5.1 Vérifier les SecurityContext

```bash
# Vérifier que les pods ne tournent pas en root
kubectl get pods -n dev -o jsonpath='{.items[*].spec.containers[*].securityContext}'

# Ajouter dans deployment.yaml si nécessaire:
securityContext:
  runAsNonRoot: true
  runAsUser: 101
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
```

### 5.2 Scanner les images avec Trivy

```bash
# Scanner l'image nginx
trivy image nginx:1.25-alpine

# Scanner les pods déployés
trivy k8s --report summary cluster
```

### 5.3 Test NetworkPolicy

```bash
# Appliquer une NetworkPolicy stricte
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: test-deny-all
  namespace: dev
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF

# Vérifier que l'application n'est plus accessible
curl http://demo-app-dev.example.com
# Devrait timeout ou échouer

# Nettoyer
kubectl delete networkpolicy test-deny-all -n dev
```

## 🔄 6. Tests de Rollback

### 6.1 Rollback via ArgoCD

```bash
# Faire un changement cassé
vim base/deployment.yaml
# Changez l'image en une version inexistante: nginx:999.999-alpine

git add base/deployment.yaml
git commit -m "test: image cassée pour test rollback"
git push

# Observer l'échec
kubectl get pods -n dev -w

# Rollback via ArgoCD UI ou CLI
argocd app rollback demo-app-dev <previous-revision>

# Ou via Git:
git revert HEAD
git push
```

### 6.2 Rollback Kubernetes natif

```bash
# Voir l'historique des déploiements
kubectl rollout history deployment -n dev dev-demo-app

# Rollback à la version précédente
kubectl rollout undo deployment -n dev dev-demo-app

# Rollback à une version spécifique
kubectl rollout undo deployment -n dev dev-demo-app --to-revision=2
```

## 📝 7. Tests de Logs et Monitoring

### 7.1 Agrégation de logs

```bash
# Voir les logs de tous les pods
kubectl logs -n dev -l app=demo-app --tail=100

# Suivre les logs en temps réel
kubectl logs -n dev -l app=demo-app -f

# Logs d'un conteneur spécifique si plusieurs conteneurs
kubectl logs -n dev <pod-name> -c nginx
```

### 7.2 Vérifier les métriques (si metrics-server installé)

```bash
# Métriques des pods
kubectl top pods -n dev

# Métriques des nodes
kubectl top nodes

# Métriques détaillées d'un pod
kubectl describe pod -n dev <pod-name> | grep -A 5 "Resource"
```

## 🎭 8. Tests de Multi-Environnement

### 8.1 Comparer dev et prod

```bash
# Voir les différences de configuration
diff <(kubectl get deployment -n dev dev-demo-app -o yaml) \
     <(kubectl get deployment -n prod prod-demo-app -o yaml)

# Comparer les ressources
kubectl get all -n dev
kubectl get all -n prod
```

### 8.2 Promouvoir de dev à prod

```bash
# Vérifier que dev fonctionne bien
kubectl get pods -n dev

# Synchroniser prod manuellement dans ArgoCD UI
# Ou forcer une sync:
argocd app sync demo-app-prod

# Vérifier le déploiement prod
kubectl rollout status deployment -n prod prod-demo-app
```

## 🧹 9. Tests de Nettoyage

### 9.1 Test de suppression avec prune

```bash
# Supprimer une ressource de Git (par exemple le HPA)
git rm base/hpa.yaml
vim base/kustomization.yaml  # Enlever hpa.yaml
git commit -m "test: suppression HPA"
git push

# Avec prune: true, ArgoCD supprime le HPA du cluster
kubectl get hpa -n dev
# Le HPA devrait disparaître après la sync
```

### 9.2 Nettoyage complet

```bash
# Supprimer les applications ArgoCD
kubectl delete application demo-app-dev demo-app-prod -n argocd

# Avec le finalizer, cela supprime aussi les ressources du cluster
# Vérifier:
kubectl get all -n dev
kubectl get all -n prod
```

## 📋 Checklist de Tests

### Avant de passer en prod

- [ ] Application démarre correctement
- [ ] Healthchecks (liveness/readiness) fonctionnent
- [ ] Service accessible en interne
- [ ] Ingress fonctionne et résout correctement
- [ ] Logs sont disponibles et pertinents
- [ ] Métriques sont collectées
- [ ] Resources requests/limits appropriées
- [ ] HPA fonctionne sous charge
- [ ] NetworkPolicies n'empêchent pas le trafic légitime
- [ ] GitOps sync fonctionne automatiquement
- [ ] Rollback fonctionne
- [ ] Pas de vulnérabilités critiques dans les images

## 🔧 Scripts de Test Automatisés

Créez un fichier `test-app.sh`:

```bash
#!/bin/bash
set -e

NAMESPACE=${1:-dev}
APP_NAME=${2:-demo-app}

echo "🧪 Tests de l'application $APP_NAME dans $NAMESPACE"

# Test 1: Deployment existe
echo "Test 1: Vérification du deployment..."
kubectl get deployment -n $NAMESPACE ${NAMESPACE}-${APP_NAME} > /dev/null
echo "✅ Deployment existe"

# Test 2: Pods en running
echo "Test 2: Vérification des pods..."
READY=$(kubectl get deployment -n $NAMESPACE ${NAMESPACE}-${APP_NAME} -o jsonpath='{.status.readyReplicas}')
if [ "$READY" -gt 0 ]; then
    echo "✅ $READY pods ready"
else
    echo "❌ Aucun pod ready"
    exit 1
fi

# Test 3: Service existe
echo "Test 3: Vérification du service..."
kubectl get service -n $NAMESPACE ${NAMESPACE}-${APP_NAME} > /dev/null
echo "✅ Service existe"

# Test 4: Test HTTP interne
echo "Test 4: Test de connectivité interne..."
kubectl run test-http --rm -i --restart=Never --image=busybox -n $NAMESPACE -- \
    wget -O- -T 5 http://${NAMESPACE}-${APP_NAME} > /dev/null 2>&1
echo "✅ Connectivité interne OK"

echo ""
echo "✅ Tous les tests passés !"
```

Bon testing ! 🚀
