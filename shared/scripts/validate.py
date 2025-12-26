#!/usr/bin/env python3
"""
OISP Event Validator

Validates that captured events match expected patterns.

Usage:
    python validate.py events.jsonl expected-events.json

Exit codes:
    0 - All validations passed
    1 - Validation failed
    2 - Error (file not found, invalid JSON, etc.)
"""

import json
import re
import sys
from pathlib import Path
from typing import Any


def load_jsonl(path: Path) -> list[dict]:
    """Load events from JSONL file."""
    events = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if line:
                events.append(json.loads(line))
    return events


def load_expected(path: Path) -> dict:
    """Load expected events schema."""
    with open(path) as f:
        return json.load(f)


def get_nested(obj: dict, path: str) -> Any:
    """Get nested value using dot notation (e.g., 'data.provider.name')."""
    parts = path.split('.')
    current = obj
    for part in parts:
        if isinstance(current, dict) and part in current:
            current = current[part]
        else:
            return None
    return current


def matches_value(actual: Any, expected: Any) -> bool:
    """Check if actual value matches expected.
    
    Expected can be:
    - Exact value: "openai" matches "openai"
    - Comparison: "> 0" matches any positive number
    - Regex: "/gpt-.*/" matches "gpt-4o-mini"
    - Type check: "string" matches any string
    - Existence: "*" matches any non-None value
    """
    if expected == "*":
        return actual is not None
    
    if isinstance(expected, str):
        # Comparison operators
        if expected.startswith("> "):
            try:
                return actual > float(expected[2:])
            except (TypeError, ValueError):
                return False
        if expected.startswith(">= "):
            try:
                return actual >= float(expected[3:])
            except (TypeError, ValueError):
                return False
        if expected.startswith("< "):
            try:
                return actual < float(expected[2:])
            except (TypeError, ValueError):
                return False
        if expected.startswith("<= "):
            try:
                return actual <= float(expected[3:])
            except (TypeError, ValueError):
                return False
        
        # Regex pattern
        if expected.startswith("/") and expected.endswith("/"):
            pattern = expected[1:-1]
            return bool(re.match(pattern, str(actual)))
        
        # Type checks
        if expected == "string":
            return isinstance(actual, str)
        if expected == "number":
            return isinstance(actual, (int, float))
        if expected == "boolean":
            return isinstance(actual, bool)
        if expected == "array":
            return isinstance(actual, list)
        if expected == "object":
            return isinstance(actual, dict)
    
    # Exact match
    return actual == expected


def validate_event(event: dict, expected: dict) -> tuple[bool, list[str]]:
    """Validate a single event against expected fields.
    
    Returns (passed, list of error messages).
    """
    errors = []
    
    # Check event_type
    if "event_type" in expected:
        if event.get("event_type") != expected["event_type"]:
            return False, [f"Event type mismatch: expected {expected['event_type']}, got {event.get('event_type')}"]
    
    # Check required fields
    for field_path, expected_value in expected.get("required_fields", {}).items():
        actual = get_nested(event, field_path)
        if not matches_value(actual, expected_value):
            errors.append(f"Field '{field_path}': expected {expected_value!r}, got {actual!r}")
    
    return len(errors) == 0, errors


def find_matching_event(events: list[dict], expected: dict) -> tuple[dict | None, list[str]]:
    """Find an event that matches the expected pattern."""
    event_type = expected.get("event_type")
    
    # Filter by event type first
    candidates = [e for e in events if e.get("event_type") == event_type]
    
    if not candidates:
        return None, [f"No events found with type '{event_type}'"]
    
    # Try each candidate
    all_errors = []
    for event in candidates:
        passed, errors = validate_event(event, expected)
        if passed:
            return event, []
        all_errors.extend(errors)
    
    return None, all_errors[:5]  # Limit error output


def validate(events_path: Path, expected_path: Path) -> bool:
    """Main validation function."""
    print(f"Validating {events_path} against {expected_path}")
    print()
    
    # Load files
    try:
        events = load_jsonl(events_path)
    except Exception as e:
        print(f"ERROR: Could not load events file: {e}")
        return False
    
    try:
        expected = load_expected(expected_path)
    except Exception as e:
        print(f"ERROR: Could not load expected events file: {e}")
        return False
    
    print(f"Loaded {len(events)} captured events")
    print(f"Checking {len(expected.get('events', []))} expected patterns")
    print()
    
    # Check minimum events
    min_events = expected.get("minimum_events", 0)
    if len(events) < min_events:
        print(f"FAIL: Expected at least {min_events} events, got {len(events)}")
        return False
    
    # Validate each expected event
    all_passed = True
    matched_events = []
    
    for i, exp in enumerate(expected.get("events", [])):
        event_type = exp.get("event_type", "unknown")
        print(f"[{i+1}] Checking {event_type}...")
        
        event, errors = find_matching_event(events, exp)
        
        if event:
            print(f"    PASS - Found matching event")
            matched_events.append(event)
        else:
            print(f"    FAIL - No matching event found")
            for error in errors:
                print(f"         - {error}")
            all_passed = False
    
    print()
    if all_passed:
        print(f"SUCCESS: All {len(expected.get('events', []))} expected events found")
    else:
        print("FAILURE: Some expected events were not found")
    
    return all_passed


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(2)
    
    events_path = Path(sys.argv[1])
    expected_path = Path(sys.argv[2])
    
    if not events_path.exists():
        print(f"ERROR: Events file not found: {events_path}")
        sys.exit(2)
    
    if not expected_path.exists():
        print(f"ERROR: Expected events file not found: {expected_path}")
        sys.exit(2)
    
    success = validate(events_path, expected_path)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()

