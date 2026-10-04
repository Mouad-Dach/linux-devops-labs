#!/bin/bash
while true; do
    echo "$(date) - myservice is running" >> /var/log/myservice.log
    sleep 5
done
