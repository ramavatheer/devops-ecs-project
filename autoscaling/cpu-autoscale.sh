#!/bin/bash

# ===== CONFIGURATION =====
CLUSTER="ecsCluster"
SERVICE="devops-service"

MIN_COUNT=1
MAX_COUNT=3

SCALE_UP_THRESHOLD=60
SCALE_DOWN_THRESHOLD=20

# ===== GET CURRENT CONTAINER COUNT =====
CURRENT_COUNT=$(aws ecs describe-services \
  --cluster $CLUSTER \
  --services $SERVICE \
  --query "services[0].runningCount" \
  --output text)

# ===== GET AVERAGE CPU UTILIZATION =====
AVG_CPU=$(aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ClusterName,Value=$CLUSTER Name=ServiceName,Value=$SERVICE \
  --statistics Average \
  --period 60 \
  --start-time $(date -u -d '2 minutes ago' +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --query "Datapoints[0].Average" \
  --output text)

# If no datapoint available, set CPU to 0
if [ "$AVG_CPU" = "None" ] || [ -z "$AVG_CPU" ]; then
    AVG_CPU=0
fi

# Remove decimal part
AVG_CPU=${AVG_CPU%.*}

echo "Average CPU: $AVG_CPU%"
echo "Current containers: $CURRENT_COUNT"

# ===== VALIDATION CHECK =====
if ! [[ "$AVG_CPU" =~ ^[0-9]+$ ]] || ! [[ "$CURRENT_COUNT" =~ ^[0-9]+$ ]]; then
    echo "Error: Invalid CPU or container count value"
    exit 1
fi

# ===== SCALING LOGIC =====
if [ "$AVG_CPU" -gt "$SCALE_UP_THRESHOLD" ] && [ "$CURRENT_COUNT" -lt "$MAX_COUNT" ]; then
    
    NEW_COUNT=$((CURRENT_COUNT + 1))

    aws ecs update-service \
      --cluster $CLUSTER \
      --service $SERVICE \
      --desired-count $NEW_COUNT \
      > /dev/null 2>&1

    echo "Scaling UP: $CURRENT_COUNT → $NEW_COUNT"

elif [ "$AVG_CPU" -lt "$SCALE_DOWN_THRESHOLD" ] && [ "$CURRENT_COUNT" -gt "$MIN_COUNT" ]; then
    
    NEW_COUNT=$((CURRENT_COUNT - 1))

    aws ecs update-service \
      --cluster $CLUSTER \
      --service $SERVICE \
      --desired-count $NEW_COUNT \
      > /dev/null 2>&1

    echo "Scaling DOWN: $CURRENT_COUNT → $NEW_COUNT"

else
    echo "No scaling action needed"
fi
