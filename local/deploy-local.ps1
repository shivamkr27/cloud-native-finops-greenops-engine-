$ErrorActionPreference = "Stop"

$Profile = if ($env:MINIKUBE_PROFILE) { $env:MINIKUBE_PROFILE } else { "aegis-greenops" }

minikube status -p $Profile | Out-Null
if ($LASTEXITCODE -ne 0) {
    minikube start -p $Profile --driver=docker
}

docker build -t batch-processor:local -f cron-scheduler/Dockerfile.batch cron-scheduler
docker build -t carbon-scheduler:local-v1 -f cron-scheduler/Dockerfile .
docker build -t greenops-dashboard:local -f greenops-dashboard/Dockerfile .

minikube -p $Profile image load batch-processor:local
minikube -p $Profile image load carbon-scheduler:local-v1
minikube -p $Profile image load greenops-dashboard:local

(Get-Content cron-scheduler/batch-deployment.yaml) -replace 'batch-processor:latest', 'batch-processor:local' | kubectl apply -f -
kubectl apply -f cron-scheduler/rbac.yaml
(Get-Content cron-scheduler/cronjob.yaml) -replace 'carbon-scheduler:latest', 'carbon-scheduler:local-v1' | kubectl apply -f -
(Get-Content greenops-dashboard/dashboard-kubernetes.yaml) -replace 'greenops-dashboard:latest', 'greenops-dashboard:local' | kubectl apply -f -

kubectl rollout status deployment/greenops-dashboard --timeout=120s
kubectl rollout status deployment/batch-processor --timeout=120s

Write-Host "Dashboard: http://$((minikube -p $Profile ip)):30505"
Write-Host "Use kubectl get cronjobs,jobs,pods to inspect the local demo."