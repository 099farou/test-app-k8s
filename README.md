# Guide de Déploiement - Application Demo K8s avec ArgoCD

## 📁 Structure du Projet

```
test-app-k8s/
├── base/                          # Configuration de base
│   ├── deployment.yaml           # Déploiement nginx
│   ├── service.yaml              # Service ClusterIP
│   ├── configmap.yaml            # Page HTML personnalisée
│   ├── ingress.yaml              # Règles d'ingress
│   └── kustomization.yaml        # Base Kustomize
├── overlays/
│   ├── dev/                      # Environnement développement
│   │   ├── kustomization.yaml    # 1 replica, namespace dev
│   │   └── ingress-patch.yaml    # demo-app-dev.example.com
│   └── prod/                     # Environnement production
│       ├── kustomization.yaml    # 3 replicas, namespace prod
│       ├── ingress-patch.yaml    # demo-app.example.com + TLS
│       └── resources-patch.yaml  # Plus de ressources
├── argocd-app-dev.yaml           # Application ArgoCD pour dev
└── argocd-app-prod.yaml          # Application ArgoCD pour prod
```

## 🚀 Étape 1 : Préparation du Repository Git

### 1.1 Créer un nouveau repository

```bash
# Sur GitHub/GitLab/Gitea, créez un nouveau repository
# Exemple: test-app-k8s
```

### 1.2 Pousser les fichiers

```bash
cd test-app-k8s
git init
git add .
git commit -m "Initial commit: demo app k8s"
git remote add origin https://github.com/VOTRE-USER/test-app-k8s.git
git push -u origin main
```

### 1.3 Mettre à jour les fichiers ArgoCD

Modifiez les fichiers `argocd-app-dev.yaml` et `argocd-app-prod.yaml` :

```yaml
spec:
  source:
    repoURL: https://github.com/VOTRE-USER/test-app-k8s.git  # ← Votre URL
```

## 📦 Étape 2 : Créer les Namespaces

```bash
# Créer les namespaces (ou laisser ArgoCD le faire avec CreateNamespace=true)
kubectl create namespace dev
kubectl create namespace prod
```

## 🔄 Étape 3 : Déployer via ArgoCD

### 3.1 Déployer l'application DEV

```bash
# Appliquer la définition ArgoCD pour dev
kubectl apply -f argocd-app-dev.yaml

# Vérifier le status
kubectl get application -n argocd demo-app-dev

# Suivre la synchronisation
kubectl get application -n argocd demo-app-dev -w
```

### 3.2 Via l'interface ArgoCD

1. Ouvrez ArgoCD dans votre navigateur
2. Vous devriez voir l'application `demo-app-dev`
3. Cliquez dessus pour voir les ressources
4. La synchronisation devrait être automatique (automated sync)

### 3.3 Déployer l'application PROD

```bash
# Appliquer la définition ArgoCD pour prod
kubectl apply -f argocd-app-prod.yaml

# Pour prod, la sync est manuelle, donc dans ArgoCD UI :
# Cliquez sur "SYNC" puis "SYNCHRONIZE"
```

## 🔍 Étape 4 : Vérifier le Déploiement

### 4.1 Vérifier les ressources DEV

```bash
# Voir tous les objets dans le namespace dev
kubectl get all -n dev

# Détails du deployment
kubectl describe deployment -n dev dev-demo-app

# Logs des pods
kubectl logs -n dev -l app=demo-app --tail=50

# Status du service
kubectl get svc -n dev

# Status de l'ingress
kubectl get ingress -n dev
kubectl describe ingress -n dev dev-demo-app
```

### 4.2 Vérifier les ressources PROD

```bash
# Même chose pour prod
kubectl get all -n prod
kubectl get ingress -n prod
```

## 🌐 Étape 5 : Configuration Réseau

### 5.1 Vérifier l'Ingress Controller

```bash
# Vérifier que votre ingress controller est actif
kubectl get pods -n ingress-nginx
# ou
kubectl get pods -n traefik

# Vérifier le service de l'ingress controller
kubectl get svc -n ingress-nginx
# ou
kubectl get svc -n traefik
```

### 5.2 Configuration DNS

**Option A : Modification locale (pour test)**

```bash
# Récupérer l'IP de votre ingress controller
kubectl get svc -n ingress-nginx ingress-nginx-controller

# Ajouter dans /etc/hosts (Linux/Mac) ou C:\Windows\System32\drivers\etc\hosts (Windows)
<IP_INGRESS>  demo-app-dev.example.com
<IP_INGRESS>  demo-app.example.com
```

**Option B : DNS réel**

Créez des enregistrements DNS A ou CNAME pointant vers l'IP de votre ingress controller.

### 5.3 Tester l'accès

```bash
# Test dev
curl http://demo-app-dev.example.com
# ou dans le navigateur

# Test prod
curl http://demo-app.example.com
```

## 🔐 Étape 6 : Configuration HTTPS (Optionnel)

### 6.1 Installer cert-manager (si pas déjà fait)

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
```

### 6.2 Créer un ClusterIssuer

```bash
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: votre-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx  # ou traefik
EOF
```

### 6.3 Activer TLS dans l'Ingress

L'ingress prod a déjà la configuration TLS commentée. Décommentez-la dans `overlays/prod/ingress-patch.yaml` et poussez vers Git.

## 🧪 Étape 7 : Tester GitOps

### 7.1 Modifier l'application

```bash
# Modifier la ConfigMap (changez le texte HTML)
vim base/configmap.yaml

# Commit et push
git add base/configmap.yaml
git commit -m "Update: changement de message"
git push
```

### 7.2 Observer ArgoCD

```bash
# Dev se synchronise automatiquement
# Attendez 3 minutes ou forcez la sync dans l'UI

# Vérifiez que les changements sont appliqués
kubectl get configmap -n dev dev-demo-app-html -o yaml
```

### 7.3 Tester le rollback

Dans l'interface ArgoCD, cliquez sur "History and Rollback" pour revenir à une version précédente.

## 📊 Étape 8 : Monitoring et Debugging

### 8.1 Vérifier la santé dans ArgoCD

```bash
# CLI ArgoCD (si installé)
argocd app get demo-app-dev
argocd app sync demo-app-dev

# Voir les événements
argocd app logs demo-app-dev --tail 50
```

### 8.2 Debugging réseau

```bash
# Test depuis un pod dans le cluster
kubectl run -it --rm debug --image=busybox --restart=Never -- sh
# Dans le pod :
wget -O- http://dev-demo-app.dev.svc.cluster.local

# Vérifier la résolution DNS
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup dev-demo-app.dev.svc.cluster.local
```

### 8.3 Vérifier les NetworkPolicies (si actives)

```bash
kubectl get networkpolicies -n dev
kubectl describe networkpolicy <name> -n dev
```

## 🎯 Cas d'Usage Courants

### Scaler l'application

```bash
# Modifier le nombre de replicas dans overlays/dev/kustomization.yaml
replicas:
  - name: demo-app
    count: 3

# Commit et push, ArgoCD sync automatiquement
```

### Changer l'image

```bash
# Dans base/deployment.yaml
image: nginx:1.26-alpine

# Commit et push
```

### Ajouter des variables d'environnement

```bash
# Dans overlays/dev/kustomization.yaml
patchesStrategicMerge:
  - env-patch.yaml

# Créer env-patch.yaml avec les variables
```

## 📝 Checklist de Vérification

- [ ] Repository Git créé et configuré
- [ ] Namespaces dev et prod créés
- [ ] ArgoCD Applications créées
- [ ] Applications synchronisées (dev auto, prod manuel)
- [ ] Pods en état Running
- [ ] Services créés et fonctionnels
- [ ] Ingress configuré avec les bons hosts
- [ ] DNS ou /etc/hosts configuré
- [ ] Application accessible via le navigateur
- [ ] Test de modification GitOps effectué

## 🔧 Commandes Utiles

```bash
# Voir toutes les applications ArgoCD
kubectl get applications -n argocd

# Forcer une synchronisation
kubectl patch application demo-app-dev -n argocd --type merge -p '{"operation": {"initiatedBy": {"username": "admin"}, "sync": {"revision": "HEAD"}}}'

# Supprimer une application (attention!)
kubectl delete application demo-app-dev -n argocd

# Voir les différences entre Git et cluster
argocd app diff demo-app-dev

# Voir l'historique des syncs
argocd app history demo-app-dev
```

## 🆘 Troubleshooting

### L'application n'apparaît pas dans ArgoCD

```bash
# Vérifier les logs ArgoCD
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller

# Vérifier les events
kubectl get events -n argocd --sort-by='.lastTimestamp'
```

### Les pods ne démarrent pas

```bash
# Vérifier les events du namespace
kubectl get events -n dev --sort-by='.lastTimestamp'

# Décrire le pod
kubectl describe pod -n dev <pod-name>

# Voir les logs
kubectl logs -n dev <pod-name>
```

### L'ingress ne fonctionne pas

```bash
# Vérifier que l'ingress controller voit l'ingress
kubectl get ingress -A

# Vérifier les logs de l'ingress controller
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller

# Tester le service directement
kubectl port-forward -n dev svc/dev-demo-app 8080:80
# Puis ouvrir http://localhost:8080
```

## 🎓 Prochaines Étapes

1. **Ajouter un HPA** (Horizontal Pod Autoscaler)
2. **Configurer des NetworkPolicies** pour sécuriser les communications
3. **Mettre en place des canary deployments** avec Argo Rollouts
4. **Ajouter Prometheus/Grafana** pour le monitoring
5. **Configurer des secrets** avec Sealed Secrets ou External Secrets

Bon déploiement ! 🚀
