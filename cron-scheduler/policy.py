#!/usr/bin/env python3


def choose_replicas(carbon_intensity, threshold=150, min_replicas=1, max_replicas=5):
    """Return the target replica count for the current grid intensity."""
    if carbon_intensity < threshold:
        return max_replicas
    return min_replicas


def parse_carbon_intensity(value, minimum=0, maximum=1000):
    """Parse and validate a dashboard carbon-intensity value."""
    try:
        parsed = int(value)
    except (TypeError, ValueError) as error:
        raise ValueError("carbon_intensity must be an integer") from error
    if not minimum <= parsed <= maximum:
        raise ValueError(f"carbon_intensity must be between {minimum} and {maximum}")
    return parsed