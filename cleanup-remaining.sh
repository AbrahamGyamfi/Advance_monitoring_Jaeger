#!/bin/bash
NAMESPACE_ID=$(aws servicediscovery list-namespaces --filters Name=NAME,Values=taskflow.local --query 'Namespaces[0].Id' --output text)
if [ "$NAMESPACE_ID" != "None" ]; then
  aws servicediscovery delete-namespace --id $NAMESPACE_ID 2>/dev/null || true
fi

aws cloudtrail delete-trail --name taskflow-trail 2>/dev/null || true

DETECTOR_ID=$(aws guardduty list-detectors --query 'DetectorIds[0]' --output text)
if [ "$DETECTOR_ID" != "None" ]; then
  aws guardduty delete-detector --detector-id $DETECTOR_ID 2>/dev/null || true
fi

aws iam remove-role-from-instance-profile --instance-profile-name taskflow-cloudwatch-role-jenkins --role-name taskflow-cloudwatch-role-jenkins 2>/dev/null || true
aws iam delete-instance-profile --instance-profile-name taskflow-cloudwatch-role-jenkins 2>/dev/null || true

echo "Cleanup complete"
