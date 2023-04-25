#!/bin/bash

cat > ./momo-store-chart/Chart.yaml <<EOF
---
apiVersion: v2
type: application
name: momo-store
description: Momo Store Helm Chart

version: ${VERSION_UPSTREAM}
appVersion: ${VERSION_UPSTREAM}

dependencies:
  - name: backend
    version: latest
  - name: frontend
    version: latest
EOF

#backend
cat > ./momo-store-chart/charts/backend/Chart.yaml <<EOF 
apiVersion: v2
name: backend
description: Backend Helm Chart
type: application

version: ${VERSION_UPSTREAM}
appVersion: ${VERSION_UPSTREAM}
EOF

#frontend
cat > ./momo-store-chart/charts/frontend/Chart.yaml <<EOF 
apiVersion: v2
name: frontend
description: Frontend Helm Chart
type: application

version: ${VERSION_UPSTREAM}
appVersion: ${VERSION_UPSTREAM}
EOF
