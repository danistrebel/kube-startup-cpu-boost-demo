#!/bin/bash

show_experiment() {
    
    local pod_resource=$(kubectl get po -l demo.kcdzurich.ch/experiment=$1 -n experiment -o json)

    local pod_status_phase=$(jq '.items[0].status.phase // "N/A"' <<< $pod_resource)

    local container_cpu=$(jq '.items[0].spec.containers[0].resources.limits.cpu // "N/A"' <<< $pod_resource)

    local final_log=$(kubectl logs -l demo.kcdzurich.ch/experiment=$1 -n experiment | grep "Started .* seconds")

    clear

    printf "Experiment: $1\n\n"
    printf "📦 Pod: $pod_status_phase\n\n"
    printf "⚡ CPU: $container_cpu (limit)\n\n"
    printf "🏁 Log: $final_log\n\n\n\n"
    printf "last update: $(date +%T)" 
}

## repeat show_experiment infinitely with a sleep of 1 second
while true; do
    show_experiment "$1"
    sleep 2
done