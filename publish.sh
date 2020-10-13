#!/bin/bash
export CHECKPOINT_SERVER="192.168.0.5"
export CHECKPOINT_USERNAME="consul_user"
export CHECKPOINT_PASSWORD="test123"
export CHECKPOINT_CONTEXT="web_api"
export CHECKPOINT_TIMEOUT=60
sleep 2
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
publish_linux
elif [[ "$OSTYPE" == "darwin"* ]]; then
publish_osx
fi