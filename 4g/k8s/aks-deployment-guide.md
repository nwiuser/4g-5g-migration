# Azure Kubernetes Service (AKS) Deployment Guide for srsRAN 4G

## Prerequisites

1. **Azure CLI installed**
   ```bash
   az --version
   ```

2. **Azure account with active subscription**
   ```bash
   az login
   az account show
   ```

3. **kubectl installed**
   ```bash
   kubectl version --client
   ```

## Step 1: Create Azure Container Registry (ACR)

```bash
# Set variables
RESOURCE_GROUP="rg-srsran-4g"
LOCATION="eastus"
ACR_NAME="acrsrsran4g"  # Must be globally unique

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create ACR
az acr create --resource-group $RESOURCE_GROUP \
  --name $ACR_NAME --sku Basic

# Login to ACR
az acr login --name $ACR_NAME
```

## Step 2: Build and Push Docker Image to ACR

```bash
# Navigate to the 4g directory
cd C:\Users\NajibNOUISSER\Desktop\srsRAN\4g-5g-migration\4g

# Tag the image
docker tag srsran:latest $ACR_NAME.azurecr.io/srsran:latest

# Push to ACR
docker push $ACR_NAME.azurecr.io/srsran:latest

# Verify the image
az acr repository list --name $ACR_NAME --output table
```

## Step 3: Create AKS Cluster

```bash
# Set variables
AKS_NAME="aks-srsran-4g"
NODE_COUNT=3
VM_SIZE="Standard_D2s_v3"

# Create AKS cluster
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_NAME \
  --node-count $NODE_COUNT \
  --node-vm-size $VM_SIZE \
  --enable-managed-identity \
  --attach-acr $ACR_NAME \
  --generate-ssh-keys

# Get AKS credentials
az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_NAME

# Verify connection
kubectl get nodes
```

## Step 4: Update the Manifest File

Edit `aks-deploy.yaml` and replace `<YOUR_ACR_NAME>` with your actual ACR name:

```bash
# Using PowerShell
(Get-Content k8s\aks-deploy.yaml) -replace '<YOUR_ACR_NAME>', '$ACR_NAME' | Set-Content k8s\aks-deploy.yaml
```

Or manually replace all occurrences of `<YOUR_ACR_NAME>.azurecr.io/srsran:latest` with `acrsrsran4g.azurecr.io/srsran:latest`

## Step 5: Deploy to AKS

```bash
# Apply the manifest
kubectl apply -f k8s/aks-deploy.yaml

# Check namespace
kubectl get namespaces

# Check deployments
kubectl get deployments -n srsran

# Check pods
kubectl get pods -n srsran

# Check services
kubectl get services -n srsran
```

## Step 6: Monitor and Verify

```bash
# Watch pods status
kubectl get pods -n srsran -w

# Check EPC logs
kubectl logs -n srsran -l app=srsepc --tail=50

# Check eNodeB logs
kubectl logs -n srsran -l app=srsenb --tail=50

# Check UE logs
kubectl logs -n srsran -l app=srsue --tail=50

# Describe a pod for troubleshooting
kubectl describe pod -n srsran <pod-name>
```

## Step 7: Access Dashboard (Optional)

```bash
# Deploy Kubernetes Dashboard
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

# Create admin service account
kubectl create serviceaccount dashboard-admin -n kubernetes-dashboard
kubectl create clusterrolebinding dashboard-admin --clusterrole=cluster-admin --serviceaccount=kubernetes-dashboard:dashboard-admin

# Get token
kubectl create token dashboard-admin -n kubernetes-dashboard

# Start proxy
kubectl proxy

# Access at: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
```

## Step 8: Scale the Deployment (Optional)

```bash
# Scale EPC
kubectl scale deployment srsepc -n srsran --replicas=2

# Scale eNodeB
kubectl scale deployment srsenb -n srsran --replicas=2

# Check HPA status
kubectl get hpa -n srsran
```

## Troubleshooting

### Issue: Image pull errors
```bash
# Verify ACR integration
az aks check-acr --resource-group $RESOURCE_GROUP --name $AKS_NAME --acr $ACR_NAME.azurecr.io
```

### Issue: Pod not starting
```bash
# Check events
kubectl get events -n srsran --sort-by='.lastTimestamp'

# Check pod details
kubectl describe pod -n srsran <pod-name>
```

### Issue: Connection failures
```bash
# Check service endpoints
kubectl get endpoints -n srsran

# Test DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -n srsran -- nslookup srsepc.srsran.svc.cluster.local
```

## Cleanup

```bash
# Delete the deployment
kubectl delete -f k8s/aks-deploy.yaml

# Delete namespace
kubectl delete namespace srsran

# Delete AKS cluster
az aks delete --resource-group $RESOURCE_GROUP --name $AKS_NAME --yes --no-wait

# Delete resource group (deletes everything)
az group delete --name $RESOURCE_GROUP --yes --no-wait
```

## Cost Optimization Tips

1. **Use smaller VMs for testing**: `Standard_B2s` instead of `Standard_D2s_v3`
2. **Scale down when not in use**: `az aks stop --name $AKS_NAME --resource-group $RESOURCE_GROUP`
3. **Use spot instances**: Add `--enable-cluster-autoscaler --node-osdisk-type Ephemeral`
4. **Set autoscaling**: Configure HPA in the manifest (already included)

## Monitoring with Azure Monitor

```bash
# Enable Container Insights
az aks enable-addons --resource-group $RESOURCE_GROUP --name $AKS_NAME --addons monitoring

# View metrics in Azure Portal
# Navigate to: AKS cluster -> Insights -> Containers
```

## Security Best Practices

1. **Enable RBAC**: Already enabled by default
2. **Use Azure Key Vault**: Store sensitive configuration
3. **Enable Pod Security Standards**: 
   ```bash
   kubectl label namespace srsran pod-security.kubernetes.io/enforce=baseline
   ```
4. **Network Policies**: Consider implementing network policies for traffic control

## Next Steps

- Set up CI/CD pipeline with Azure DevOps or GitHub Actions
- Configure persistent storage for logs and metrics
- Implement monitoring with Azure Monitor or Prometheus
- Set up alerts for pod failures
- Configure backup and disaster recovery
