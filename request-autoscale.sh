#!/bin/bash

CLUSTER="ecsCluster"
SERVICE="devops-service"

MIN_COUNT=1
MAX_COUNT=4

SCALE_UP_THRESHOLD=50
SCALE_DOWN_THRESHOLD=10

COOLDOWN_SECONDS=180
STATE_FILE="/home/ec2-user/devops-ecs-project/scale_state.txt"
LOG_FILE="/home/ec2-user/devops-ecs-project/request-scale.log"

METRICS_URL="http://localhost:8080/metrics"

timestamp() {
  date +"%Y-%m-%d %H:%M:%S"
}

log() {
  echo "$(timestamp) - $1" >> $LOG_FILE
}

get_requests() {
  curl -s $METRICS_URL | \
  grep traefik_router_requests_total | \
  grep -v '^#' | \
  awk '{sum+=$2} END {print sum}'
}

REQ1=$(get_requests)
sleep 60
REQ2=$(get_requests)

if [ -z "$REQ1" ] || [ -z "$REQ2" ]; then
  log "Metrics not available"
  exit 1
fi

REQUESTS_PER_MIN=$((REQ2 - REQ1))

CURRENT_COUNT=$(aws ecs describe-services \
  --cluster $CLUSTER \
  --services $SERVICE \
  --query "services[0].runningCount" \
  --output text)

NOW=$(date +%s)
LAST_SCALE_TIME=0

if [ -f "$STATE_FILE" ]; then
  LAST_SCALE_TIME=$(cat $STATE_FILE)
fi

TIME_DIFF=$((NOW - LAST_SCALE_TIME))

log "Requests/min: $REQUESTS_PER_MIN | Containers: $CURRENT_COUNT | Time since last scale: ${TIME_DIFF}s"

# ===== COOLDOWN CHECK =====
if [ "$TIME_DIFF" -lt "$COOLDOWN_SECONDS" ]; then
  log "Cooldown active. No scaling."
  exit 0
fi

# ===== SCALING LOGIC =====
if [ "$REQUESTS_PER_MIN" -gt "$SCALE_UP_THRESHOLD" ] && [ "$CURRENT_COUNT" -lt "$MAX_COUNT" ]; then

  NEW_COUNT=$((CURRENT_COUNT + 1))

  aws ecs update-service \
    --cluster $CLUSTER \
    --service $SERVICE \
    --desired-count $NEW_COUNT > /dev/null 2>&1

  echo $NOW > $STATE_FILE
  log "Scaling UP → $NEW_COUNT"

elif [ "$REQUESTS_PER_MIN" -lt "$SCALE_DOWN_THRESHOLD" ] && [ "$CURRENT_COUNT" -gt "$MIN_COUNT" ]; then

  NEW_COUNT=$((CURRENT_COUNT - 1))

  aws ecs update-service \
    --cluster $CLUSTER \
    --service $SERVICE \
    --desired-count $NEW_COUNT > /dev/null 2>&1

  echo $NOW > $STATE_FILE
  log "Scaling DOWN → $NEW_COUNT"

else
  log "No scaling action needed"
fi
