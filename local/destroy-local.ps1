$ErrorActionPreference = "Stop"

kubectl delete -f greenops-dashboard/dashboard-kubernetes.yaml --ignore-not-found
kubectl delete -f cron-scheduler/cronjob.yaml --ignore-not-found
kubectl delete -f cron-scheduler/rbac.yaml --ignore-not-found
kubectl delete -f cron-scheduler/batch-deployment.yaml --ignore-not-found

Write-Host "Aegis GreenOps application resources removed. Minikube itself was kept intact."