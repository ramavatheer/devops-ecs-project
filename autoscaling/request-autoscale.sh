#!/bin/bash


PROMETHEUS_URL="http://13.233.161.113:9090"
CLUSTER_NAME="ecsCluster"
SERVICE_NAME="devops-service"

MAX_CONTAINERS=5
MIN_CONTAINERS=1

SCALE_UP_THRESHOLD=5
SCALE_DOWN_THRESHOLD=1

echo "-----------------------------"
echo "Autoscale check started at $(date)"


REQUEST_RATE=$(curl -s -g "$PROMETHEUS_URL/api/v1/query?query=sum(rate(traefik_service_requests_total[1m]))" \
| jq -r '.data.result[0].value[1] // "0"')

if [ -z "$REQUEST_RATE" ]; then
    REQUEST_RATE=0
fi

echo "Current Request Rate: $REQUEST_RATE req/sec"


CURRENT_COUNT=$(aws ecs describe-services \
--cluster $CLUSTER_NAME \
--services $SERVICE_NAME \
--query "services[0].desiredCount" \
--output text)

echo "Current ECS service size: $CURRENT_COUNT"

if (( $(echo "$REQUEST_RATE > $SCALE_UP_THRESHOLD" | bc -l) )); then

    NEW_COUNT=$((CURRENT_COUNT+1))

    if [ "$NEW_COUNT" -gt "$MAX_CONTAINERS" ]; then
        NEW_COUNT=$MAX_CONTAINERS
    fi

    if [ "$NEW_COUNT" != "$CURRENT_COUNT" ]; then

        echo "Scaling UP service to $NEW_COUNT containers"

        aws ecs update-service \
        --cluster $CLUSTER_NAME \
        --service $SERVICE_NAME \
        --desired-count $NEW_COUNT

    else
        echo "Already at max container limit"
    fi
fi


# SCALE DOWN
if (( $(echo "$REQUEST_RATE < $SCALE_DOWN_THRESHOLD" | bc -l) )); then

    NEW_COUNT=$((CURRENT_COUNT-1))

    if [ "$NEW_COUNT" -lt "$MIN_CONTAINERS" ]; then
        NEW_COUNT=$MIN_CONTAINERS
    fi

    if [ "$NEW_COUNT" != "$CURRENT_COUNT" ]; then

        echo "Scaling DOWN service to $NEW_COUNT containers"

        aws ecs update-service \
        --cluster $CLUSTER_NAME \
        --service $SERVICE_NAME \
        --desired-count $NEW_COUNT

    else
        echo "Already at minimum container limit"
    fi
fi

echo "Autoscale check finished"
echo "-----------------------------"
