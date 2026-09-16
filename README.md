# Aegis GreenOps Engine

A local Kubernetes prototype for carbon-aware workload scaling and FinOps waste visibility. The project runs on Docker Desktop and Minikube so the complete demo can be tested without creating AWS infrastructure or paying for cloud compute.

## What This Project Does

The project contains a small control loop:

1. The dashboard exposes a simulated grid carbon intensity.
2. The carbon scheduler reads that value every minute.
3. The scheduler changes the `batch-processor` Deployment replica count.
4. A clean grid (`carbon_intensity < 150`) scales the workload to 5 replicas.
5. A dirty grid (`carbon_intensity >= 150`) scales it back to 1 replica.
6. The dashboard displays the current carbon value, replicas, modeled watts, node state, and FinOps waste opportunities.

The default dashboard value is `220 gCO2/kWh`, so the initial state is the low-replica dirty-grid mode.

## Implemented Components

| Component | Location | Purpose |
| --- | --- | --- |
| GreenOps dashboard | `greenops-dashboard/` | Flask UI, carbon control slider, status APIs, waste controls, and Prometheus metrics |
| Carbon scheduler | `cron-scheduler/carbon_job.py` | Reads grid intensity and scales the target Deployment |
| Scaling policy | `cron-scheduler/policy.py` | Validates carbon values and selects 1 or 5 replicas |
| Batch workload | `cron-scheduler/batch_processor.py` | Demo workload managed by the carbon policy |
| Kubernetes CronJob | `cron-scheduler/cronjob.yaml` | Runs the scheduler every minute |
| RBAC | `cron-scheduler/rbac.yaml` | Allows the scheduler to read and scale the workload |
| Local deployment | `local/deploy-local.ps1` | Builds images, starts Minikube when needed, loads images, and applies manifests |
| Local cleanup | `local/destroy-local.ps1` | Removes application resources and optional monitoring resources |
| Optional telemetry | `kepler-telemetry/`, `monitoring/` | Kepler, Prometheus, Grafana, Kubecost, and alert configuration |
| Cloud templates | `karpenter/` | Optional Karpenter AWS templates; not used by the local quick start |

## Why Docker Desktop and Minikube?

The local setup is intentional:

- **Minikube** provides a local Kubernetes cluster without an AWS or Azure cluster.
- **Docker Desktop** builds and runs the container images locally.
- Images are loaded directly into Minikube, so the demo does not need a public container registry.
- The local workflow avoids EC2 instances, load balancers, managed Kubernetes fees, and cloud egress charges.
- The same Kubernetes objects still demonstrate Deployments, Services, CronJobs, RBAC, probes, resource requests, and scaling behavior.

This is a cost-saving development and demonstration setup. It is not a replacement for production cloud infrastructure.

## Requirements

Install and start:

- Docker Desktop
- Minikube
- `kubectl`
- PowerShell
- Python 3.10+ if you want to run the policy tests directly

The local deployment script uses the Docker driver and the Minikube profile `aegis-greenops` by default.

## Start the Project

Open PowerShell in the repository root:

```powershell
cd "D:\sem 6\cloud-native-finops-greenops-engine-main"
.\local\deploy-local.ps1
```

The script:

- starts the `aegis-greenops` Minikube profile if it is not running;
- builds the batch, scheduler, and dashboard images;
- loads those images into Minikube;
- applies the workload, RBAC, CronJob, dashboard, and Service manifests;
- waits for the dashboard and batch Deployment rollouts.

### Open the dashboard

For reliable Windows access with the Docker driver, run this in a second PowerShell window:

```powershell
kubectl port-forward svc/greenops-dashboard 5000:80
```

Open:

**http://localhost:5000**

Keep the port-forward command running while using the dashboard. The dashboard health endpoint is `http://localhost:5000/healthz`; readiness is available at `http://localhost:5000/readyz`.

The Kubernetes NodePort is `30505`. Minikube can print its current IP with:

```powershell
minikube -p aegis-greenops ip
```

On Windows with the Docker driver, the port-forward URL is preferred because the NodePort address may not be directly reachable from the host browser.

## Demonstrate Carbon-Aware Scaling

1. Open `http://localhost:5000`.
2. Start with `220 gCO2/kWh`. The workload should remain at 1 replica.
3. Move the slider below `150`, for example to `100`.
4. Wait for the next one-minute CronJob run.
5. Check the workload:

   ```powershell
   kubectl get deployment batch-processor
   kubectl get jobs,pods
   ```

6. The Deployment should move to 5 replicas.
7. Move the slider back to `220` and wait for the next CronJob run; it should return to 1 replica.

The scheduler can use the internal dashboard API by default. If `ELECTRICITY_MAPS_API_KEY` and `ELECTRICITY_MAPS_ZONE` are configured, it can query Electricity Maps instead and fall back to the internal API if that request fails.

## Useful Dashboard APIs

With the port-forward active:

```powershell
Invoke-WebRequest http://localhost:5000/healthz
Invoke-WebRequest http://localhost:5000/readyz
Invoke-WebRequest http://localhost:5000/api/status
Invoke-WebRequest http://localhost:5000/metrics
```

The dashboard also accepts a carbon override:

```powershell
Invoke-RestMethod -Method Post `
  -Uri http://localhost:5000/api/carbon-intensity `
  -ContentType "application/json" `
  -Body '{"carbon_intensity":100}'
```

## Stop and Close the Project

### Stop application resources

This removes the application Deployments, Services, CronJob, RBAC, and related optional manifests:

```powershell
.\local\destroy-local.ps1
```

### Stop Minikube completely

This powers off the local Kubernetes node but keeps the profile for the next start:

```powershell
minikube stop -p aegis-greenops
```

### Start again later

```powershell
minikube start -p aegis-greenops --driver=docker
.\local\deploy-local.ps1
```

If the port-forward is running, press `Ctrl+C` in that terminal to close it.

## Cost and Resource Notes

The validated local workflow does **not** create an AWS bill. It uses local Docker and Minikube resources only.

Keeping it running still consumes:

- local CPU and RAM;
- Docker image and Kubernetes storage on disk;
- electricity and laptop/desktop capacity;
- additional local resources if optional Kepler, Prometheus, Grafana, or Kubecost components are installed.

For the lowest local resource usage, stop both the port-forward and Minikube when finished. The optional `start.sh` path installs heavier telemetry and cost-analysis components; use the PowerShell local workflow for the lightweight core demo.

AWS/Karpenter files in `karpenter/` are templates only. They do not provision AWS resources unless someone explicitly applies them in an AWS Kubernetes environment. Any real cloud cost or savings claim requires a separate cloud deployment, billing data, and a measured baseline.

## Tests

Run the policy unit tests from the repository root:

```powershell
python -m unittest discover -s tests -p "test_*.py"
```

The tests cover clean-grid scaling, the threshold boundary, custom replica limits, and carbon input validation.

## Troubleshooting

### Check the cluster

```powershell
minikube status -p aegis-greenops
kubectl get pods,deployments,services,cronjobs
```

### Dashboard is not reachable

Make sure the cluster is running and start the port-forward again:

```powershell
minikube start -p aegis-greenops --driver=docker
kubectl port-forward svc/greenops-dashboard 5000:80
```

### Scheduler jobs are not scaling the workload

Inspect recent jobs and logs:

```powershell
kubectl get jobs
kubectl get pods
kubectl logs job/<job-name>
```

The CronJob runs once per minute. A value below `150` selects 5 replicas; `150` or above selects 1 replica.

## Scope and Limitations

- Energy and waste values in the dashboard are modeled demo values, not hardware measurements or cloud invoices.
- Kepler, Prometheus, Grafana, and Kubecost are optional integrations and are not required for the core local scaling loop.
- Karpenter manifests describe a future AWS adaptation and are not exercised by the local deployment script.
- The project demonstrates the control logic and Kubernetes workflow; it does not claim a measured percentage of cloud savings.

## Related Documentation

- [Resume and demo notes](docs/resume-and-demo.md)
- [Local deployment script](local/deploy-local.ps1)
- [Local cleanup script](local/destroy-local.ps1)