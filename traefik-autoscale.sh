#!/bin/bash

CLUSTER="ecsCluster"
SERVICE="devops-service"
MIN_TASKS=1
MAX_TASKS=3
SCALE_UP_THRESHOLD=20
SCALE_DOWN_THRESHOLD=5
COOLDOWN=120

STATE_FILE="/home/ec2-user/scale_state.txt"
LOG_FILE="/home/ec2-user/scale.log"

now=$(date +%s)

# Get current total requests
current=$(curl -s http://localhost:8080/metrics | grep traefik_router_requests_total | awk '{sum += $2} END {print sum}')

if [ -z "$current" ]; then
    echo "Metrics not available"
    exit 0
fi

# Load previous state
if [ -f "$STATE_FILE" ]; then
    read last_time last_requests last_scale < "$STATE_FILE"
else
    last_time=$now
    last_requests=$current
    last_scale=0
fi

delta=$((current - last_requests))

# Get running containers
running=$(aws ecs describe-services \
    --cluster $CLUSTER \
    --services $SERVICE \
    --query "services[0].runningCount" \
    --output text)

echo "$(date) | Requests in interval: $delta | Running: $running" >> $LOG_FILE

# Cooldown check
if [ $((now - last_scale)) -lt $COOLDOWN ]; then
    echo "$(date) | In cooldown period" >> $LOG_FILE
    echo "$now $current $last_scale" > $STATE_FILE
    exit 0
fi

# Scale Up
if [ "$delta" -gt "$SCALE_UP_THRESHOLD" ] && [ "$running" -lt "$MAX_TASKS" ]; then
    new_count=$((running + 1))
    aws ecs update-service \
        --cluster $CLUSTER \
        --service $SERVICE \
        --desired-count $new_count > /dev/null
    echo "$(date) | Scaling UP to $new_count" >> $LOG_FILE
    echo "$now $current $now" > $STATE_FILE
    exit 0
fi

# Scale Down
if [ "$delta" -lt "$SCALE_DOWN_THRESHOLD" ] && [ "$running" -gt "$MIN_TASKS" ]; then
    new_count=$((running - 1))
    aws ecs update-service \
        --cluster $CLUSTER \
        --service $SERVICE \
        --desired-count $new_count > /dev/null
    echo "$(date) | Scaling DOWN to $new_count" >> $LOG_FILE
    echo "$now $current $now" > $STATE_FILE
    exit 0
fi

# No scaling
echo "$now $current $last_scale" > $STATE_FILE
echo "$(date) | No scaling needed" >> $LOG_FILE
