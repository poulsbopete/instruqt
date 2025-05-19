## Connect to Elastic Observability (Serverless)

To send telemetry data from the OpenTelemetry demo to Elastic, follow these steps to spin up a serverless Observability project and get your endpoint and API key.

---

### 🚀 Step 1: Log into Elastic Cloud

1. Go to [https://cloud.elastic.co](https://cloud.elastic.co)
2. Sign in or create a free account

---

### 📦 Step 2: Create a Serverless Observability Project

1. Click **"Create Deployment"**
2. Select **"Serverless Project"**
3. Choose **Observability**
4. Name your deployment (e.g., `otel-demo`)
5. Click **"Create Project"** and wait ~1–2 minutes

---

### 🔐 Step 3: Generate an API Key

1. Click **Manage Project**
2. Navigate to **Security > API Keys**
3. Click **Create API Key**
   - Name: `instruqt-demo-key`
   - Roles: Select:
     - `Ingest pipelines`
     - `APM Agent`
     - `Ingest Writer`
4. Copy the API key

Paste this into the **Elastic API Key** input field on the right → ✅

---

### 🌐 Step 4: Get the OTLP Endpoint

1. Go to **Observability > Add data**
2. Click **OpenTelemetry > Use Elastic APM with OpenTelemetry**
3. Copy the `OTLP/HTTP endpoint` (e.g., `https://...elastic-cloud.com:443`)

Paste this into the **Elastic OTLP Endpoint** field on the right → ✅

---

Once entered, start the challenge to deploy and forward data using your values!
