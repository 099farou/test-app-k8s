#!/bin/bash
# Script de déploiement rapide - Demo App K8s

set -e

echo "🚀 Déploiement de l'application demo via ArgoCD"
echo ""

# Variables
ARGOCD_NAMESPACE="argocd"
DEV_NAMESPACE="dev"
PROD_NAMESPACE="prod"

# Fonction pour afficher les sections
section() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  $1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# 1. Vérifier les prérequis
section "1. Vérification des prérequis"

if ! kubectl version --client &> /dev/null; then
    echo "❌ kubectl n'est pas installé"
    exit 1
fi
echo "✅ kubectl est installé"

if ! kubectl get namespace $ARGOCD_NAMESPACE &> /dev/null; then
    echo "❌ ArgoCD n'est pas installé (namespace $ARGOCD_NAMESPACE non trouvé)"
    echo "   Installez ArgoCD avec:"
    echo "   kubectl create namespace argocd"
    echo "   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
    exit 1
fi
echo "✅ ArgoCD est installé"

# 2. Créer les namespaces
section "2. Création des namespaces"

for ns in $DEV_NAMESPACE $PROD_NAMESPACE; do
    if kubectl get namespace $ns &> /dev/null; then
        echo "✅ Namespace $ns existe déjà"
    else
        kubectl create namespace $ns
        echo "✅ Namespace $ns créé"
    fi
done

# 3. Déployer les applications ArgoCD
section "3. Déploiement des applications ArgoCD"

echo "📝 Assurez-vous d'avoir modifié les fichiers argocd-app-*.yaml avec votre URL Git !"
read -p "Voulez-vous continuer ? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Annulé. Modifiez les fichiers puis relancez ce script."
    exit 0
fi

# Dev
echo "Déploiement de l'application DEV..."
kubectl apply -f argocd-app-dev.yaml
echo "✅ Application DEV déployée"

# Prod
echo "Déploiement de l'application PROD..."
kubectl apply -f argocd-app-prod.yaml
echo "✅ Application PROD déployée"

# 4. Attendre la synchronisation
section "4. Attente de la synchronisation"

echo "Attente de la synchronisation de l'app DEV (30 secondes)..."
sleep 30

# 5. Vérifier le déploiement
section "5. Vérification du déploiement"

echo "=== Applications ArgoCD ==="
kubectl get applications -n $ARGOCD_NAMESPACE

echo ""
echo "=== Ressources DEV ==="
kubectl get all -n $DEV_NAMESPACE

echo ""
echo "=== Ressources PROD ==="
kubectl get all -n $PROD_NAMESPACE

echo ""
echo "=== Ingress DEV ==="
kubectl get ingress -n $DEV_NAMESPACE

echo ""
echo "=== Ingress PROD ==="
kubectl get ingress -n $PROD_NAMESPACE

# 6. Informations d'accès
section "6. Informations d'accès"

echo "📝 Configuration requise pour accéder à l'application:"
echo ""

# Récupérer l'IP de l'ingress controller
INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "N/A")
if [ "$INGRESS_IP" == "N/A" ]; then
    INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.externalIPs[0]}' 2>/dev/null || echo "N/A")
fi

if [ "$INGRESS_IP" == "N/A" ]; then
    echo "⚠️  Impossible de récupérer l'IP de l'ingress controller"
    echo "    Vérifiez votre ingress controller avec:"
    echo "    kubectl get svc -n ingress-nginx"
else
    echo "🌐 IP de l'ingress controller: $INGRESS_IP"
    echo ""
    echo "Ajoutez ces lignes à votre /etc/hosts :"
    echo ""
    echo "$INGRESS_IP  demo-app-dev.example.com"
    echo "$INGRESS_IP  demo-app.example.com"
    echo ""
fi

echo "🔗 URLs de l'application:"
echo "   DEV:  http://demo-app-dev.example.com"
echo "   PROD: http://demo-app.example.com"
echo ""

# 7. Accès ArgoCD
section "7. Accès à l'interface ArgoCD"

echo "Pour accéder à ArgoCD:"
echo ""
echo "1. Récupérer le mot de passe admin:"
echo "   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
echo ""
echo "2. Port-forward vers ArgoCD:"
echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo ""
echo "3. Ouvrir: https://localhost:8080"
echo "   Username: admin"
echo "   Password: (celui récupéré à l'étape 1)"
echo ""

# 8. Commandes utiles
section "8. Commandes utiles"

cat << 'EOF'
# Voir les logs des pods
kubectl logs -n dev -l app=demo-app --tail=50 -f

# Redémarrer un deployment
kubectl rollout restart deployment -n dev dev-demo-app

# Voir les événements
kubectl get events -n dev --sort-by='.lastTimestamp'

# Test en local (port-forward)
kubectl port-forward -n dev svc/dev-demo-app 8080:80
# Puis: http://localhost:8080

# Forcer une sync ArgoCD (dev)
kubectl patch application demo-app-dev -n argocd --type merge -p '{"spec":{"syncPolicy":{"syncOptions":["CreateNamespace=true"]}}}'

# Supprimer tout (ATTENTION!)
kubectl delete application demo-app-dev demo-app-prod -n argocd
kubectl delete namespace dev prod
EOF

echo ""
echo "✅ Déploiement terminé !"
echo ""
echo "📚 Consultez le README.md pour plus de détails"
