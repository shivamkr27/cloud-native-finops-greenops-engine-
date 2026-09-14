# Resume and Demo Evidence

## Validated scope

This repository validates a local Kubernetes prototype using Docker and Minikube. The dashboard, carbon-aware CronJob, Prometheus metrics, and policy tests are executable without an AWS account or cloud spend.

Karpenter and AWS manifests are adaptation templates. They are not presented as proof of real EC2 provisioning or AWS cost savings.

## Recommended resume bullets

- Built a Kubernetes-based FinOps and GreenOps platform integrating Prometheus, Grafana, Kubecost, and energy-oriented telemetry for workload cost and sustainability observability.
- Implemented carbon-aware workload scaling that adjusts batch capacity between 1 and 5 replicas based on configurable grid carbon intensity.
- Configured Karpenter-compatible Spot and consolidation templates and created a local dashboard for workload, energy, and cost simulation.

Do not claim a measured 35% AWS saving unless an AWS baseline and optimized run have been measured with billing data. Local results should be described as modeled or simulated.

## Demo evidence

1. Run `local/deploy-local.ps1` from PowerShell.
2. Open the printed dashboard URL.
3. Start at `220 gCO2/kWh`; explain the dirty-grid one-replica mode.
4. Move the slider to `100 gCO2/kWh`.
5. After the next CronJob run, show the Deployment at five replicas with `kubectl get deployment batch-processor`.
6. Open `/metrics` through port-forwarding and show the carbon, replica-related, energy, and waste metrics.
7. Return to `220` and show the workload scale down on the next run.
8. Save terminal output and screenshots as evidence for the repository release notes.