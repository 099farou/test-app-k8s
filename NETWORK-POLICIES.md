# Exemples de NetworkPolicies pour votre application

## 1. Deny All par défaut (bonne pratique de sécurité)

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: dev  # ou prod
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

## 2. Autoriser le trafic Ingress uniquement depuis l'Ingress Controller

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ingress-controller
  namespace: dev
spec:
  podSelector:
    matchLabels:
      app: demo-app
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx  # Adapter selon votre ingress
    ports:
    - protocol: TCP
      port: 80
```

## 3. Autoriser le trafic Egress vers Internet (pour mises à jour, APIs externes)

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-egress-internet
  namespace: dev
spec:
  podSelector:
    matchLabels:
      app: demo-app
  policyTypes:
  - Egress
  egress:
  # DNS
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
  # HTTP/HTTPS
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 80
    - protocol: TCP
      port: 443
```

## 4. Autoriser la communication entre pods de la même application

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-same-app
  namespace: dev
spec:
  podSelector:
    matchLabels:
      app: demo-app
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: demo-app
```

## 5. NetworkPolicy complète pour l'application demo

Créez un fichier `network-policy.yaml` dans `base/`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: demo-app-netpol
spec:
  podSelector:
    matchLabels:
      app: demo-app
  policyTypes:
  - Ingress
  - Egress
  
  # Autoriser l'ingress depuis l'ingress controller
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 80
  
  # Autoriser l'egress vers DNS et internet
  egress:
  # DNS
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - protocol: UDP
      port: 53
  # Internet pour CDN, etc.
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 80
    - protocol: TCP
      port: 443
```

## 6. Appliquer les NetworkPolicies

Pour les intégrer avec Kustomize, ajoutez dans `base/kustomization.yaml`:

```yaml
resources:
  - deployment.yaml
  - service.yaml
  - configmap.yaml
  - ingress.yaml
  - network-policy.yaml  # Ajouter cette ligne
```

## Tester les NetworkPolicies

### Test 1: Vérifier que le trafic depuis l'ingress fonctionne

```bash
# Cela devrait fonctionner
curl http://demo-app-dev.example.com
```

### Test 2: Vérifier que le trafic direct est bloqué

```bash
# Créer un pod de test
kubectl run test-pod --rm -it --image=busybox -- sh

# Dans le pod, essayer d'accéder au service
wget -O- http://dev-demo-app.dev.svc.cluster.local
# Cela devrait être bloqué si la NetworkPolicy est bien configurée
```

### Test 3: Vérifier depuis un pod dans le bon namespace

```bash
# Depuis un pod avec le bon label, cela devrait fonctionner
kubectl run test-allowed --rm -it --image=busybox -n dev \
  --labels="app=demo-app" -- sh

# Puis tester
wget -O- http://dev-demo-app
```

## Debugging NetworkPolicies

```bash
# Voir les NetworkPolicies actives
kubectl get networkpolicies -n dev

# Décrire une NetworkPolicy
kubectl describe networkpolicy demo-app-netpol -n dev

# Vérifier les labels des pods
kubectl get pods -n dev --show-labels

# Vérifier les labels des namespaces
kubectl get namespace ingress-nginx --show-labels
```

## Bonnes Pratiques

1. **Commencez par deny-all**: Bloquez tout par défaut, puis autorisez explicitement
2. **Soyez spécifique**: Utilisez des selectors précis (labels, namespaces)
3. **Testez progressivement**: Ajoutez les policies une par une
4. **Documentez**: Commentez vos policies pour expliquer leur but
5. **Auditez régulièrement**: Vérifiez que vos policies sont toujours pertinentes

## Scénarios Courants

### Autoriser Prometheus à scraper les métriques

```yaml
ingress:
- from:
  - namespaceSelector:
      matchLabels:
        name: monitoring
  ports:
  - protocol: TCP
    port: 9090  # Port des métriques
```

### Autoriser l'accès à une base de données

```yaml
egress:
- to:
  - namespaceSelector:
      matchLabels:
        name: database
  - podSelector:
      matchLabels:
        app: postgresql
  ports:
  - protocol: TCP
    port: 5432
```

### Isolation complète entre dev et prod

Assurez-vous que les namespaces dev et prod ont des labels distincts et n'autorisez pas le trafic cross-namespace.
