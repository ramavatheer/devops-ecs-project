#!/bin/sh

echo "Starting autoscaling checks..."

/scripts/cpu-autoscale.sh
/scripts/request-autoscale.sh
/scripts/traefik-autoscale.sh

echo "Autoscaling checks completed"
