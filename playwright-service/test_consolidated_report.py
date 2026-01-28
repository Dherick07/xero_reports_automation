"""
Test script for Consolidated Report download.

This script tests the consolidated report download feature which:
1. Downloads Activity Statement
2. Downloads Payroll Activity Summary
3. Consolidates both into a single Excel file

Usage:
    python test_consolidated_report.py
"""

import requests
import json
from datetime import datetime

API_BASE_URL = "http://localhost:8000/api"
TENANT_NAME = "Marsill Pty Ltd"
TENANT_ID = "!mkK34"

TEST_PERIODS = [
    {"month": 10, "year": 2025, "name": "October 2025"},
    {"month": 11, "year": 2025, "name": "November 2025"},
    {"month": 12, "year": 2025, "name": "December 2025"},
]


def check_authentication():
    """Check if the browser is authenticated."""
    try:
        response = requests.get(f"{API_BASE_URL}/auth/status")
        auth_status = response.json()
        if auth_status.get("logged_in"):
            print("✓ Authenticated")
            return True
        else:
            print("✗ Not authenticated")
            print("  Please run: Invoke-RestMethod -Method POST -Uri 'http://localhost:8000/api/auth/setup'")
            return False
    except Exception as e:
        print(f"✗ Error checking auth status: {e}")
        return False


def test_consolidated_report(month: int, year: int, period_name: str):
    """Test downloading consolidated report for a specific period."""
    
    print(f"\n{'='*60}")
    print(f"Testing Consolidated Report: {period_name}")
    print(f"{'='*60}")
    
    request_body = {
        "tenant_id": TENANT_ID,
        "tenant_name": TENANT_NAME,
        "month": month,
        "year": year,
        "find_unfiled": False
    }
    
    print(f"Workflow: Activity Statement → Payroll Summary → Consolidate")
    print("This may take 2-3 minutes...")
    
    try:
        response = requests.post(
            f"{API_BASE_URL}/reports/consolidated",
            json=request_body,
            timeout=300
        )
        
        result = response.json()
        
        print(f"\n{'-'*40}")
        print("RESULT")
        print(f"{'-'*40}")
        
        if result.get("success"):
            print("✓ SUCCESS!")
            
            activity = result.get("activity_statement", {})
            if activity.get("success"):
                print(f"  ✓ Activity Statement: {activity.get('file_name')}")
            else:
                print(f"  ✗ Activity Statement: {activity.get('error')}")
            
            payroll = result.get("payroll_summary", {})
            if payroll.get("success"):
                print(f"  ✓ Payroll Summary: {payroll.get('file_name')}")
            else:
                print(f"  ✗ Payroll Summary: {payroll.get('error')}")
            
            consolidated = result.get("consolidated_file", {})
            if consolidated:
                print(f"\n  📁 Consolidated File:")
                print(f"     Name: {consolidated.get('file_name')}")
                print(f"     Path: {consolidated.get('file_path')}")
                print(f"     Sheets: {consolidated.get('sheets_count')}")
            else:
                print(f"\n  ⚠️ No consolidated file created")
        else:
            print("✗ FAILED")
            if result.get("errors"):
                for error in result["errors"]:
                    print(f"  Error: {error}")
        
        return result.get("success", False)
        
    except requests.exceptions.Timeout:
        print("✗ Request timed out (>5 minutes)")
        return False
    except Exception as e:
        print(f"✗ Error: {e}")
        return False


def main():
    print("="*60)
    print("CONSOLIDATED REPORT TEST SUITE")
    print("="*60)
    print(f"Testing {len(TEST_PERIODS)} different periods")
    print("="*60)
    
    print("\n[Step 1] Checking authentication...")
    if not check_authentication():
        return
    
    results = []
    for i, period in enumerate(TEST_PERIODS, 1):
        print(f"\n[Test {i}/{len(TEST_PERIODS)}]")
        success = test_consolidated_report(
            month=period["month"],
            year=period["year"],
            period_name=period["name"]
        )
        results.append({"period": period["name"], "success": success})
    
    print("\n" + "="*60)
    print("TEST SUMMARY")
    print("="*60)
    
    passed = sum(1 for r in results if r["success"])
    
    for r in results:
        status = "✓ PASS" if r["success"] else "✗ FAIL"
        print(f"  {status}: {r['period']}")
    
    print(f"\nTotal: {passed}/{len(results)} passed")
    
    if passed == len(results):
        print("\n🎉 All tests passed!")
    print("="*60)


if __name__ == "__main__":
    main()
