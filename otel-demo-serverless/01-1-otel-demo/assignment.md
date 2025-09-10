---
slug: 1-otel-demo
id: hbp4xaxw6tex
type: challenge
title: 1 - OTel Demo
teaser: Create Elastic Serverless O11Y instance with OTel Demo
notes:
- type: text
  contents: "<video src=\"../assets/elastic_o11y.mp4\" controls></video>\n\n\U0001F3D7️
    K8s → Elastic Observability in ~30 Minutes\n\nSpin up the OpenTelemetry Demo on
    Kubernetes, stream metrics, traces, logs into Elastic Serverless , flip a few
    chaos flags, and watch things light up. Low drama, high signal. ✨"
tabs:
- id: cgsfdg9bbuiy
  title: K8 Terminal
  type: terminal
  hostname: kubernetes
- id: e5qr8gynvon0
  title: K8 Editor
  type: code
  hostname: kubernetes
  path: /root
difficulty: ""
enhanced_loading: null
---
# 🚀 Elastic Serverless + OpenTelemetry Demo Lab

Spin up the OpenTelemetry Demo on Kubernetes and ship **metrics, traces, and logs** to **Elastic Serverless (Cloud)**. Fast path, zero Docker drama.

---

## 🎯 Quick Start

### 1) Create your Elastic project
- Go to [Elastic Cloud](https://cloud.elastic.co)
- Create **Serverless → Elastic Observability** (name it `otel-lab`)

### 2) Grab the OTLP settings
In your project: **Add data → Kubernetes → OpenTelemetry (Full Observability)** and copy:
- `ELASTIC_OTLP_ENDPOINT`
- `ELASTIC_API_KEY`

### 3) Edit your values file
Open in the Editor tab **`$HOME/elastic-demo.yaml`**, then paste/update from what you copied above
PASTE_ELASTIC_OTLP_ENDPOINT_HERE
PASTE_ELASTIC_API_KEY_HERE

### 4) Deploy the OpenTelemetry Demo
From the Terminal tab:

```
helm upgrade --install otel-demo \
  open-telemetry/opentelemetry-demo \
  --version 0.31.0 \
  -n otel-demo --create-namespace \
  -f $HOME/elastic-demo.yaml
```

⸻

## 🔧 Break Stuff on Purpose! (with Feature Flags)

Enable a specific flag:
```
toggle_flag otel-demo adServiceFailure ENABLED
```

Enable/disable all:
```
toggle_all_flags otel-demo ENABLED
```

```
toggle_all_flags otel-demo DISABLED
```


⸻

## 🤖 Build Alerts with AI

1.	Open Kibana from your Elastic Cloud project (Serverless)
2.	Open AI Assistant
3.	Ask: `Create an alert policy that detects issues in the OpenTelemetry demo.`
4.	Review & apply

⸻

## ✅ Done When…

* Helm release otel-demo is deployed in namespace otel-demo
* You see data in Elastic (Services/APM, Logs, Metrics)
* (Optional) Feature-flag failures trigger alerts

⸻

🩺 Quick Troubleshooting

### Config

Verify $HOME/elastic-demo.yaml has no PASTE_ELASTIC… placeholders


### Collector
```
kubectl -n otel-demo get deploy | grep otel
kubectl -n otel-demo logs deploy/otel-demo-otelcol
kubectl -n otel-demo get cm otel-demo-otelcol -o yaml | grep -A3 otlphttp/elastic
```

### K8s Health

```
kubectl -n otel-demo get pods
kubectl -n otel-demo get events --sort-by=.lastTimestamp | tail -n 30
```

⸻

## 📚 Resources

* [Elastic Observability Docs](https://www.elastic.co/guide/en/observability/current/index.html)
* [OpenTelemetry Docs](https://opentelemetry.io/docs/)
* [Elastic Cloud Console](https://cloud.elastic.co)


