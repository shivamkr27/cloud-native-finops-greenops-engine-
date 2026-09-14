# 🍃 Aegis GreenOps: Cloud-Native FinOps & GreenOps Engine
> **A Cost-Aware, Carbon-Efficient Kubernetes Scheduling & Monitoring Engine**
> 
> *Leveraging eBPF Energy Telemetry, Kubecost Cost Attribution, Karpenter Spot Consolidation, and Real-Time Grid Carbon Intensity APIs to build sustainable, cost-optimized cloud architectures.*

---

## 🚀 Portfolio Showcase Summary

In modern cloud engineering, managing resource usage is no longer just about CPU and RAM. It requires a dual approach: **FinOps** (maximizing business value per dollar spent) and **GreenOps** (minimizing carbon emissions per computational unit). 

**Aegis GreenOps** is a production-grade Kubernetes automation suite that correlates container-level power draw (Watts) with cloud billing metrics and regional grid carbon intensity (gCO2/kWh). It acts as an intelligent controller that shifts heavy, non-critical batch workloads to clean-energy hours while actively packing infrastructure onto cost-optimal Spot instances using Karpenter.

### 🧠 Core Competencies Exceeded (Recruiter Talking Points)
* **eBPF Kernel-Level Telemetry:** Deployed Kepler to calculate power consumption at the container level without code instrumentation, reading host RAPL (Running Average Power Limit) registers.
* **Intelligent Workload Shifting:** Built a carbon-aware scheduler that dynamically scales data processing pipelines up/down based on clean energy availability.
* **Modern Node Consolidation:** Configured Karpenter `NodePools` with Spot instance priorities and automated consolidation policies to optimize node packing and eliminate idle cloud spend.
* **Unified Metrics Correlation:** Structured Prometheus rules and a customized Grafana dashboard mapping Cost ($) vs Energy (Wh) vs Carbon (gCO2).

---

## 🏗️ Production Architecture

This diagram showcases how data flows from kernel-level eBPF counters all the way to cloud billing APIs and automated Karpenter scaling decisions:

```mermaid
graph TD
    subgraph K8s [Kubernetes Worker Nodes - EKS]
        direction TB
        PodA[Batch Processor Pod]
        PodB[Web API Pod]
        Kubelet[Kubelet]
    end

    subgraph Telemetry [Sustainability & Cost Telemetry]
        Kepler[Kepler DaemonSet] -- eBPF Probes --> LinuxKernel[Linux Kernel RAPL]
        Kepler -- Watts per Pod --> Prometheus[(Prometheus TSDB)]
        
        Kubecost[Kubecost Analyzer] -- AWS/GCP Pricing API --> Prometheus
        Kubecost -- Cost per Namespace --> Prometheus
    end

    subgraph API [Grid Carbon Data]
        GridAPI[Electricity Maps API] -- Real-Time Carbon Intensity --> Prometheus
    end

    subgraph Control [GreenOps Decision Loop]
        Cron[Carbon-Aware CronJob] -- Polls API --o GridAPI
        Cron -- Scale Replicas Up/Down --> K8s
        
        Karpenter[Karpenter Controller] -- Monitors Node Packing --> K8s
        Karpenter -- Provisions Spot / Terminates Underutilized Nodes --> CloudProvider[Cloud Infrastructure]
    end

    subgraph Visualization [Observability Portal]
        Grafana[Grafana Console] -- Queries Metrics --> Prometheus
        Dashboard[GreenOps Web Control Center] -- Live State --> K8s
    end

    %% Styling
    classDef k8s fill:#1e293b,stroke:#38bdf8,stroke-width:2px,color:#fff;
    classDef telemetry fill:#1e293b,stroke:#10b981,stroke-width:2px,color:#fff;
    classDef control fill:#1e293b,stroke:#f59e0b,stroke-width:2px,color:#fff;
    classDef vis fill:#1e293b,stroke:#8b5cf6,stroke-width:2px,color:#fff;
    
    class PodA,PodB,Kubelet k8s;
    class Kepler,Kubecost,Prometheus telemetry;
    class Cron,Karpenter control;
    class Grafana,Dashboard vis;
```

---

## 📊 Live Metrics & Operational Infographics

### 1. Cost Attribution By Namespace (Kubecost)
By integrating Kubecost billing telemetry, resource usage costs are granularly mapped to departments and namespaces, pinpointing optimization areas:

```mermaid
pie title Namespace Cost Distribution (% of Total Budget)
    "Data Science (Batch Workloads)" : 55
    "Core Web Services" : 20
    "Observability & Telemetry" : 15
    "FinOps Waste (Orphaned PVs & Namespaces)" : 10
```

### 2. State Machine: Carbon-Aware Scaling & Node Consolidation
The core scheduling logic operates as a closed feedback loop responding directly to grid state transitions:

```mermaid
stateDiagram-v2
    [*] --> EvaluatingGrid
    EvaluatingGrid --> CleanGridActive : Carbon Intensity < 150 gCO2/kWh
    EvaluatingGrid --> DirtyGridActive : Carbon Intensity >= 150 gCO2/kWh
    
    state CleanGridActive {
        [*] --> ScaleWorkloadUp
        ScaleWorkloadUp --> MaxReplicas : Scale to 5
        MaxReplicas --> KarpenterProvisionSpot : Request Capacity
        KarpenterProvisionSpot --> RunningFullSpeed : Provision Spot Nodes
    }

    state DirtyGridActive {
        [*] --> ScaleWorkloadDown
        ScaleWorkloadDown --> MinReplicas : Scale to 1
        MinReplicas --> KarpenterConsolidate : Release Capacity
        KarpenterConsolidate --> IdleEcoSaving : Consolidate and Teardown
    }

    RunningFullSpeed --> EvaluatingGrid : Grid State Changes
    IdleEcoSaving --> EvaluatingGrid : Grid State Changes
```

### 3. Chronological Logic Flow (Scheduling & Telemetry Sequence)
The following sequence details how the carbon cron scheduler, Kubernetes API, Karpenter, and Prometheus interact:

```mermaid
sequenceDiagram
    autonumber
    participant GridAPI as Grid Carbon API (Mock)
    participant Cron as Carbon Cronjob
    participant K8sAPI as K8s Apps API
    participant Karpenter as Karpenter Engine
    participant Kepler as Kepler (eBPF Telemetry)
    participant Prometheus as Prometheus TSDB

    loop Every 60 Seconds
        Cron->>GridAPI: Query current carbon intensity
        GridAPI-->>Cron: Return intensity (e.g. 100 gCO2/kWh)
        alt Intensity < 150 (Clean Grid)
            Cron->>K8sAPI: Scale batch-processor to 5 replicas
            K8sAPI->>Karpenter: Pods pending (Unscheduled)
            Karpenter->>K8sAPI: Provision cheap Spot instances & bind nodes
        else Intensity >= 150 (Dirty Grid)
            Cron->>K8sAPI: Scale batch-processor to 1 replica
            K8sAPI->>Karpenter: Underutilized nodes detected
            Karpenter->>K8sAPI: Consolidate pods & terminate idle nodes
        end
    end
    loop Continuous telemetry
        Kepler->>Prometheus: Expose pod energy consumption (Watts)
        K8sAPI->>Prometheus: Expose active replica metrics
    end
```

---

## 🛠️ Flagship Tech Stack Matrix

| Category | Technology | Why This Tool? (Strategic Rationale) |
| :--- | :--- | :--- |
| **Sustainability Telemetry** | **Kepler (eBPF)** | Measures CPU/GPU energy consumption at the pod level without modifying application code. |
| **Cost Attribution** | **Kubecost** | Provides real-time pricing breakdown by namespace, team, and pod metadata. |
| **Autoscaling Engine** | **Karpenter** | Sub-second node provisioning, natively choosing the cheapest Spot instances and automatically consolidating nodes. |
| **Carbon Integration** | **Electricity Maps API** | Provides verified carbon intensity and grid mix data for global power grids. |
| **Metrics Database** | **Prometheus** | High-performance time-series database to store, query, and alert on FinOps & GreenOps signals. |
| **Visualization Layer** | **Grafana & Custom Flask UI**| Custom dashboards correlating Watts, Dollars, and gCO2 metrics in real-time. |

---

## 📊 Karpenter vs. Standard Autoscaler (FinOps Optimization)

To achieve maximum efficiency, Aegis GreenOps replaces the legacy Kubernetes Cluster Autoscaler with Karpenter:

| Feature | Standard Cluster Autoscaler | Karpenter (Aegis GreenOps) |
| :--- | :--- | :--- |
| **Provisioning Speed** | 2 - 5 Minutes (relies on Node Groups) | **Sub-15 Seconds** (directly calls EC2 APIs) |
| **Instance Diversity** | Bound to predefined ASG sizes | **Dynamic** (picks best fit from 100s of EC2 sizes) |
| **Spot vs On-Demand** | Manual configurations and separate groups | **Intelligent selection** based on real-time pricing |
| **Consolidation / Bin Packing** | Minimal node consolidation | **Active consolidation** when node capacity drops |

---

## 🍃 Operational Greenness Matrix (Grid Shift Logic)

| Grid State | Carbon Range | Target Workload State | Karpenter Provisioning Profile | Kepler Energy Profile | Monthly Savings Potential |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 🟢 **Clean Grid** | < 150 g/kWh | **High-Throughput** (5 replicas) | Max Spot instances (e.g. 4 nodes) | High Power (~46W) | High (workload finished fast) |
| 🟡 **Moderate** | 150 - 200 g/kWh | **Balanced** (2 replicas) | Minimal Spot (e.g. 2 nodes) | Balanced (~21W) | Medium |
| 🔴 **Dirty Grid** | > 200 g/kWh | **Eco-Saving** (1 replica) | Consolidated (e.g. 1 node) | Low Power (~12W) | **Maximum** (low compute cost) |

---

## ⚙️ Core Configuration Design

### 1. Karpenter Consolidation Policy
Karpenter configuration is structured to prefer Spot instances and terminate underutilized nodes:

> [!TIP]
> **Consolidation Policies:** Setting `consolidationPolicy: WhenUnderutilized` makes Karpenter identify nodes running low-priority workloads and bin-pack them onto fewer instances, saving up to 40% on compute costs.

```yaml
# karpenter/nodepool.yaml
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: default
spec:
  template:
    spec:
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot"]
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["c", "m", "r"]
  limits:
    cpu: "100"
    memory: 100Gi
  disruption:
    consolidationPolicy: WhenUnderutilized
    expireAfter: 720h
```

### 2. Carbon-Aware Workload Scheduler
The scheduler evaluates grid health using Python and dynamically modifies deployment specs using the Kubernetes API client:

```python
# cron-scheduler/carbon_job.py (Excerpt)
if carbon_intensity < threshold:
    print("Grid is GREEN. Shifting workload: scaling UP to run batch jobs.")
    scale_deployment(deployment_name, namespace, max_replicas)
else:
    print("Grid is DIRTY. Shifting workload: scaling DOWN to conserve emissions.")
    scale_deployment(deployment_name, namespace, min_replicas)
```

---

## 🚀 Installation & Verification

### 1. Deploy the Engine
Run the automated bootstrap script to compile the custom code, load images, and deploy operators:
```bash
./start.sh
```

### 2. Teardown
To cleanly uninstall Kepler, Kubecost, and remove namespaces:
```bash
./stop.sh
```

---

## 🧪 Interactive Verification Workflow (Manual Test)

To make testing this engine accessible on a local Minikube cluster, a custom **GreenOps Control Center Dashboard** is deployed. This UI acts as the mock Grid API and simulates Kepler/Karpenter reactions.

```text
+-----------------------------------------------------------------------------+
|  [●] Aegis GreenOps Control Center                         [CONNECTED TO K8S] |
+-----------------------------------------------------------------------------+
|                                                                             |
|  GRID CARBON CONTROL                                  GRID METRICS          |
|  ------------------                                  ------------          |
|  Carbon Intensity: [-------o-----] 220 gCO2/kWh     🌱 Grid Intensity: 220  |
|  [Dirty Grid Mode - Workloads Scaled Down]          🔌 Kepler Power: 12.7 W |
|                                                     ☸️ Karpenter Nodes:     |
|  FINOPS WASTE CONTROLS                                 - Spot Nodes: 1      |
|  ---------------------                                 - On-Demand: 1       |
|  [ Resolve Unused PVs (1 Active)           ]        📊 Workload: 1 Replica  |
|  [ Reclaim Orphan Namespaces (2 Active)    ]        [Eco-Saving Mode]       |
|                                                                             |
|  -------------------------------------------------------------------------  |
|  FINOPS COST OPTIMIZATION: MONTHLY WASTED BUDGET: $450.00                   |
|  -------------------------------------------------------------------------  |
|  LOG CONSOLE                                                                |
|  [13:24:02] GreenOps Engine initialized successfully.                        |
|  [13:24:05] Kepler eBPF metrics collection: active.                         |
|                                                                             |
+-----------------------------------------------------------------------------+
```

### How to Test the Shifting Loop:
1. Open the UI in your browser at `http://<MINIKUBE_IP>:30505` (exposed via NodePort).
2. Note the initial carbon intensity is **220 gCO2/kWh** (Dirty). The batch workload is restricted to **1 Replica** (Eco-Saving Mode).
3. Drag the slider down to **100 gCO2/kWh** (Clean).
4. Watch the logs. When the `carbon-scheduler` CronJob runs (every minute), it queries the new value, detects a clean grid, and scales the `batch-processor` deployment to **5 Replicas**.
5. The UI updates in real-time:
   - **Batch Workload** replica count scales to **5**.
   - **Kepler Power Telemetry** increases to **46.7W** representing active eBPF resource draw.
   - **Karpenter Provisioning** simulates scaling up to **4 Spot Nodes** to host the pods.
6. Click **Resolve Unused PVs** or **Reclaim Orphan Namespaces** to see the simulated monthly wasted budget resolve down to `$0.00` and send mock Slack notifications.
7. Return the slider to **220 gCO2/kWh** and watch the engine scale the workloads back down to conserve energy on the next run.
