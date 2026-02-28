#!/bin/bash
sleep 10
curl -f http://localhost:5000/health || exit 1
