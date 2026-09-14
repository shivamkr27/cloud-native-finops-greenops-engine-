#!/usr/bin/env python3
import os
import sys
import urllib.request
import json

from policy import choose_replicas

try:
    from kubernetes import client, config
except ImportError:
    client = None
    config = None

def get_carbon_intensity():
    # If a real API key is configured, query the real Electricity Maps API
    api_key = os.getenv("ELECTRICITY_MAPS_API_KEY")
    zone = os.getenv("ELECTRICITY_MAPS_ZONE", "US-CA")
    
    if api_key:
        print(f"Electricity Maps API Key detected. Querying real carbon intensity for zone {zone}...")
        url = f"https://api.electricitymap.org/v3/carbon-intensity/latest?zone={zone}"
        req = urllib.request.Request(url, headers={"auth-token": api_key})
        try:
            with urllib.request.urlopen(req) as response:
                data = json.loads(response.read().decode())
                return int(data.get("carbonIntensity", 200))
        except Exception as e:
            print(f"Error querying Electricity Maps API: {e}. Falling back to mock URL.")

    # Otherwise query our internal mock GreenOps Dashboard Carbon API
    mock_url = os.getenv("GRID_API_URL", "http://greenops-dashboard.default.svc.cluster.local/api/carbon-intensity")
    print(f"Querying GreenOps mock carbon grid API at {mock_url}...")
    try:
        with urllib.request.urlopen(mock_url, timeout=5) as response:
            data = json.loads(response.read().decode())
            return int(data.get("carbon_intensity", 200))
    except Exception as e:
        print(f"Warning: Could not fetch carbon intensity from mock API: {e}. Falling back to default.")
        return 220 # Default dirty grid value

def scale_deployment(name, namespace, replicas):
    print(f"Scaling deployment '{name}' in namespace '{namespace}' to {replicas} replicas...")
    if client is None or config is None:
        print("Kubernetes client not installed; skipping scale operation in mock mode.")
        return
    try:
        config.load_incluster_config()
    except Exception:
        print("Failed to load in-cluster config, falling back to kube_config...")
        config.load_kube_config()
    
    apps_v1 = client.AppsV1Api()
    body = {"spec": {"replicas": replicas}}
    try:
        apps_v1.patch_namespaced_deployment_scale(name, namespace, body)
        print(f"Successfully scaled deployment '{name}' to {replicas} replicas.")
    except Exception as e:
        print(f"Error scaling deployment: {e}")
        sys.exit(1)

def main():
    threshold = int(os.getenv("CARBON_THRESHOLD", "150"))
    deployment_name = os.getenv("TARGET_DEPLOYMENT", "batch-processor")
    namespace = os.getenv("TARGET_NAMESPACE", "default")
    min_replicas = int(os.getenv("MIN_REPLICAS", "1"))
    max_replicas = int(os.getenv("MAX_REPLICAS", "5"))

    carbon_intensity = get_carbon_intensity()
    print(f"Current Carbon Intensity: {carbon_intensity} gCO2/kWh")
    print(f"Carbon Threshold: {threshold} gCO2/kWh")

    target_replicas = choose_replicas(
        carbon_intensity,
        threshold=threshold,
        min_replicas=min_replicas,
        max_replicas=max_replicas,
    )
    if target_replicas == max_replicas:
        print("Grid is GREEN. Shifting workload: scaling UP to run batch jobs.")
        scale_deployment(deployment_name, namespace, target_replicas)
    else:
        print("Grid is DIRTY. Shifting workload: scaling DOWN to conserve emissions.")
        scale_deployment(deployment_name, namespace, target_replicas)

if __name__ == "__main__":
    main()
