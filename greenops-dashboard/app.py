#!/usr/bin/env python3
import os
import time
from pathlib import Path

try:
    from flask import Flask, render_template, jsonify, request
except ImportError:
    Flask = None

    class _MockRequest:
        method = "GET"
        json = None

    request = _MockRequest()

    def render_template(template_name):
        template_path = Path(__file__).resolve().parent / "templates" / template_name
        return template_path.read_text(encoding="utf-8")

    def jsonify(*args, **kwargs):
        if args and kwargs:
            payload = dict(*args, **kwargs)
        elif args:
            payload = args[0]
        else:
            payload = kwargs
        return payload

try:
    from kubernetes import client, config
except ImportError:
    client = None
    config = None

if Flask is not None:
    app = Flask(__name__)
else:
    class _MockFlaskApp:
        def route(self, *_args, **_kwargs):
            def decorator(func):
                return func

            return decorator

        def run(self, *_args, **_kwargs):
            print("Flask is not installed; running in mock mode.")

    app = _MockFlaskApp()

# Try to load Kubernetes configuration
k8s_available = False
if config is not None:
    try:
        config.load_incluster_config()
        k8s_available = True
        print("Loaded in-cluster Kubernetes config.")
    except Exception:
        try:
            config.load_kube_config()
            k8s_available = True
            print("Loaded local kube_config.")
        except Exception:
            print("Running in Standalone Mock mode (no Kubernetes access).")
else:
    print("Kubernetes client not installed; running in Standalone Mock mode.")

# Global State
state = {
    "carbon_intensity": 220,  # Default dirty grid
    "spot_nodes": 2,
    "ondemand_nodes": 1,
    "unused_pv": 1,
    "orphan_namespaces": 2,
    "waste_savings": 450.00, # USD per month
    "logs": [
        {"time": time.strftime("%H:%M:%S"), "message": "GreenOps Engine initialized successfully."},
        {"time": time.strftime("%H:%M:%S"), "message": "Karpenter node consolidation rules loaded: WhenUnderutilized."},
        {"time": time.strftime("%H:%M:%S"), "message": "Kepler eBPF metrics collection: active (RAPL/ACPI emulation)."}
    ]
}

def add_log(message):
    state["logs"].append({
        "time": time.strftime("%H:%M:%S"),
        "message": message
    })
    # Limit logs to last 20
    if len(state["logs"]) > 20:
        state["logs"].pop(0)

def get_live_replicas():
    if not k8s_available:
        return 1
    try:
        apps_v1 = client.AppsV1Api()
        dep = apps_v1.read_namespaced_deployment("batch-processor", "default")
        return dep.spec.replicas or 0
    except Exception as e:
        print(f"Error reading deployment: {e}")
        return 1

def update_karpenter_simulation():
    # Simulate Karpenter provisioning/consolidating based on carbon intensity
    if state["carbon_intensity"] < 150:
        # Green grid: More batch workload replicas running
        state["spot_nodes"] = 4
        state["ondemand_nodes"] = 1
    else:
        # Dirty grid: Workloads scaled down
        state["spot_nodes"] = 1
        state["ondemand_nodes"] = 1

@app.route("/")
def index():
    return render_template("index.html")

@app.route("/api/carbon-intensity", methods=["GET", "POST"])
def carbon_intensity():
    if request.method == "POST":
        data = request.json or {}
        new_val = int(data.get("carbon_intensity", 220))
        state["carbon_intensity"] = new_val
        add_log(f"Carbon intensity manually overridden to {new_val} gCO2/kWh.")
        update_karpenter_simulation()
        return jsonify({"status": "success", "carbon_intensity": state["carbon_intensity"]})
    return jsonify({"carbon_intensity": state["carbon_intensity"]})

@app.route("/api/status")
def status():
    # Update state before returning
    update_karpenter_simulation()
    
    # Read live replicas of batch-processor
    live_replicas = get_live_replicas()
    
    # Calculate simulated Kepler Container Watts based on replicas
    base_watts = 4.2
    batch_watts = live_replicas * 8.5
    total_watts = round(base_watts + batch_watts, 2)
    
    return jsonify({
        "carbon_intensity": state["carbon_intensity"],
        "spot_nodes": state["spot_nodes"],
        "ondemand_nodes": state["ondemand_nodes"],
        "unused_pv": state["unused_pv"],
        "orphan_namespaces": state["orphan_namespaces"],
        "waste_savings": state["waste_savings"],
        "live_replicas": live_replicas,
        "total_watts": total_watts,
        "logs": state["logs"]
    })

@app.route("/api/toggle-waste-alert", methods=["POST"])
def toggle_waste_alert():
    data = request.json or {}
    alert_type = data.get("type", "pv")
    if alert_type == "pv":
        state["unused_pv"] = 0 if state["unused_pv"] > 0 else 1
        status_msg = "Cleaned up" if state["unused_pv"] == 0 else "Detected"
        add_log(f"Slack Waste Alert: {status_msg} unused PV (saving $120/mo).")
    elif alert_type == "namespace":
        state["orphan_namespaces"] = 0 if state["orphan_namespaces"] > 0 else 2
        status_msg = "Reclaimed" if state["orphan_namespaces"] == 0 else "Flagged"
        add_log(f"Slack Waste Alert: {status_msg} 2 orphan namespaces (saving $330/mo).")
    
    # Recalculate savings
    state["waste_savings"] = (state["unused_pv"] * 120.00) + (state["orphan_namespaces"] * 165.00)
    return jsonify({"status": "success", "unused_pv": state["unused_pv"], "orphan_namespaces": state["orphan_namespaces"], "savings": state["waste_savings"]})

@app.route("/metrics")
def metrics():
    # Expose custom Prometheus metrics representing the state
    live_replicas = get_live_replicas()
    base_watts = 4.2
    batch_watts = live_replicas * 8.5
    total_watts = round(base_watts + batch_watts, 2)
    
    lines = [
        "# HELP greenops_grid_carbon_intensity_gco2_kwh Real-time carbon grid intensity in gCO2/kWh",
        "# TYPE greenops_grid_carbon_intensity_gco2_kwh gauge",
        f"greenops_grid_carbon_intensity_gco2_kwh {state['carbon_intensity']}",
        
        "# HELP greenops_karpenter_spot_nodes Karpenter provisioned Spot instances",
        "# TYPE greenops_karpenter_spot_nodes gauge",
        f"greenops_karpenter_spot_nodes {state['spot_nodes']}",
        
        "# HELP greenops_karpenter_ondemand_nodes Karpenter provisioned On-Demand instances",
        "# TYPE greenops_karpenter_ondemand_nodes gauge",
        f"greenops_karpenter_ondemand_nodes {state['ondemand_nodes']}",
        
        "# HELP greenops_finops_waste_unused_pv Number of unused persistent volumes",
        "# TYPE greenops_finops_waste_unused_pv gauge",
        f"greenops_finops_waste_unused_pv {state['unused_pv']}",
        
        "# HELP greenops_finops_waste_orphan_namespaces Number of orphan namespaces",
        "# TYPE greenops_finops_waste_orphan_namespaces gauge",
        f"greenops_finops_waste_orphan_namespaces {state['orphan_namespaces']}",
        
        "# HELP greenops_finops_waste_saving_opportunity_dollars Monthly cost saving opportunities in USD",
        "# TYPE greenops_finops_waste_saving_opportunity_dollars gauge",
        f"greenops_finops_waste_saving_opportunity_dollars {state['waste_savings']}",
        
        "# HELP kepler_container_joules_total Cumulative energy consumption in Joules",
        "# TYPE kepler_container_joules_total counter",
        # We simulate this value incrementing over time to keep Prometheus rate calculators happy
        f'kepler_container_joules_total{{container_name="batch-processor", pod_name="batch-processor-pod"}} {int(time.time() * total_watts)}'
    ]
    return "\n".join(lines), 200, {"Content-Type": "text/plain; charset=utf-8"}

if __name__ == "__main__":
    port = int(os.getenv("PORT", 5000))
    app.run(host="0.0.0.0", port=port)
