# Aspire Dashboard

The .NET Aspire Dashboard is a standalone web app that shows real-time logs, traces, and metrics sent to it over OpenTelemetry (OTLP). Point any OpenTelemetry-instrumented app at it to inspect telemetry during local development.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Files](#files)
4. [Installation](#installation)
5. [Managing the Service](#managing-the-service)
6. [Management Script Commands](#management-script-commands)
7. [Connecting to Aspire Dashboard](#connecting-to-aspire-dashboard)
8. [Usage Examples](#usage-examples)
9. [Running Without systemd](#running-without-systemd)
10. [Data Persistence and Backups](#data-persistence-and-backups)
11. [Health Checks](#health-checks)
12. [Troubleshooting](#troubleshooting)
13. [Security Notes](#security-notes)
14. [Uninstall](#uninstall)
15. [Additional Resources](#additional-resources)

---

## Overview

| Property | Value |
|----------|-------|
| Container image | `mcr.microsoft.com/dotnet/aspire-dashboard:latest` |
| Container name | `aspire-dashboard` |
| Service user | `aspire-dashboard` |
| systemd unit | `aspire-dashboard.service` |
| Network mode | `bridge`, with ports published to the host |
| Dashboard UI | `http://localhost:18888` |
| OTLP gRPC endpoint | `http://localhost:18889` |
| OTLP HTTP endpoint | `http://localhost:18890` |
| Data path | None. Telemetry is held in memory only |
| Upstream | <https://learn.microsoft.com/dotnet/aspire/fundamentals/dashboard/standalone> |

---

## Prerequisites

- Docker installed and running
- Root or sudo access
- Ports 18888, 18889, and 18890 free on the host

---

## Files

| File | Purpose | Installed to |
|------|---------|--------------|
| `aspire-dashboard.sh` | Container management script (`start`, `stop`, `status`, `health`) | `/opt/aspire-dashboard/aspire-dashboard.sh` |
| `aspire-dashboard.service` | systemd unit file | `/etc/systemd/system/aspire-dashboard.service` |
| `install.sh` | One-time installation script (requires root) | Not installed |
| `README.md` | This document | Not installed |

---

## Installation

1. Run the install script from this directory:

   ```bash
   cd /path/to/Data/aspire-dashboard
   sudo ./install.sh
   ```

2. Start the service for the first time:

   ```bash
   sudo systemctl start aspire-dashboard.service
   ```

3. Confirm it is healthy:

   ```bash
   sudo -u aspire-dashboard /opt/aspire-dashboard/aspire-dashboard.sh health
   ```

**What `install.sh` does:**

1. Creates the `aspire-dashboard` system user with home directory `/opt/aspire-dashboard`
2. Adds `aspire-dashboard` to the `docker` group
3. Enables user lingering (`loginctl enable-linger aspire-dashboard`)
4. Copies `aspire-dashboard.sh` to `/opt/aspire-dashboard/` and makes it executable
5. Copies `aspire-dashboard.service` to `/etc/systemd/system/`
6. Reloads systemd and enables the service to start on boot

---

## Managing the Service

```bash
# Start
sudo systemctl start aspire-dashboard.service

# Stop
sudo systemctl stop aspire-dashboard.service

# Check status
sudo systemctl status aspire-dashboard.service

# Enable auto-start on boot (done by install.sh)
sudo systemctl enable aspire-dashboard.service

# Disable auto-start
sudo systemctl disable aspire-dashboard.service

# View logs
sudo journalctl -xeu aspire-dashboard.service

# Follow logs in real time
sudo journalctl -fu aspire-dashboard.service
```

---

## Management Script Commands

Run the management script directly as the service user:

```bash
sudo -u aspire-dashboard /opt/aspire-dashboard/aspire-dashboard.sh <command>
```

| Command | Action |
|---------|--------|
| `start` | Removes any existing `aspire-dashboard` container and starts a new one |
| `stop` | Stops and removes the container |
| `status` | Shows the container's state (`docker ps -a`) |
| `health` | Confirms the container is running and the dashboard UI on port 18888 responds |

---

## Connecting to Aspire Dashboard

| Endpoint | URL | Use |
|----------|-----|-----|
| Dashboard UI | `http://localhost:18888` | Open in a browser |
| OTLP gRPC | `http://localhost:18889` | Exporter protocol `grpc` |
| OTLP HTTP | `http://localhost:18890` | Exporter protocol `http/protobuf` |

The container runs with `DOTNET_DASHBOARD_UNSECURED_ALLOW_ANONYMOUS=true`, so the UI needs no login token and the OTLP endpoints need no API key.

Most OpenTelemetry SDKs can be pointed at the dashboard with environment variables alone:

```bash
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:18889
export OTEL_EXPORTER_OTLP_PROTOCOL=grpc
export OTEL_SERVICE_NAME=my-service
```

---

## Usage Examples

### .NET

Requires the `OpenTelemetry.Extensions.Hosting`, `OpenTelemetry.Instrumentation.AspNetCore`, and `OpenTelemetry.Exporter.OpenTelemetryProtocol` NuGet packages.

```csharp
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOpenTelemetry()
    .ConfigureResource(r => r.AddService("MyService"))
    .WithTracing(t => t
        .AddAspNetCoreInstrumentation()
        .AddOtlpExporter(o => o.Endpoint = new Uri("http://localhost:18889")));

var app = builder.Build();
app.Run();
```

### Python

Requires `pip install opentelemetry-sdk opentelemetry-exporter-otlp-proto-grpc`.

```python
from opentelemetry import trace
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter

provider = TracerProvider(resource=Resource.create({"service.name": "my-service"}))
provider.add_span_processor(
    BatchSpanProcessor(OTLPSpanExporter(endpoint="http://localhost:18889", insecure=True))
)
trace.set_tracer_provider(provider)

with trace.get_tracer(__name__).start_as_current_span("hello"):
    print("Span sent to the Aspire Dashboard")
```

---

## Running Without systemd

For a quick test, or on a machine without systemd (such as Windows 11), run the container directly.

**Linux / macOS:**

```bash
docker run -d \
  --name aspire-dashboard \
  -p 18888:18888 \
  -p 18889:18889 \
  -p 18890:18890 \
  -e DOTNET_DASHBOARD_UNSECURED_ALLOW_ANONYMOUS=true \
  mcr.microsoft.com/dotnet/aspire-dashboard:latest
```

**Windows 11 (PowerShell):**

```powershell
docker run -d `
  --name aspire-dashboard `
  -p 18888:18888 `
  -p 18889:18889 `
  -p 18890:18890 `
  -e DOTNET_DASHBOARD_UNSECURED_ALLOW_ANONYMOUS=true `
  mcr.microsoft.com/dotnet/aspire-dashboard:latest
```

---

## Data Persistence and Backups

The dashboard has no data volume. It keeps telemetry in memory, so all logs, traces, and metrics are lost when the container restarts. There is nothing to back up.

---

## Health Checks

```bash
# Check service status
sudo systemctl status aspire-dashboard.service

# Run the built-in health check
sudo -u aspire-dashboard /opt/aspire-dashboard/aspire-dashboard.sh health

# Check the container's own health status
docker inspect --format '{{.State.Health.Status}}' aspire-dashboard

# Test the dashboard endpoint directly
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:18888

# View container logs
docker logs aspire-dashboard
```

Expected:

- The built-in check prints `Aspire Dashboard is healthy and accessible at http://localhost:18888`.
- `docker inspect` prints `healthy`.
- `curl` prints `200`.

---

## Troubleshooting

### Service fails to start: port already in use

**Cause:** Another process is listening on 18888, 18889, or 18890.

**Fix:** Find and stop the other process:

```bash
sudo ss -ltnp | grep -E ':1888[89]\b|:18890\b'
```

To use other host ports instead, change `PORT_1`, `PORT_2`, and `PORT_3` at the top of `aspire-dashboard.sh`, then reinstall and restart:

```bash
sudo ./install.sh
sudo systemctl restart aspire-dashboard.service
```

### Connection refused

**Cause:** The container is not running, or Docker is down.

**Fix:**

```bash
sudo systemctl status docker
sudo systemctl status aspire-dashboard.service
docker port aspire-dashboard
sudo journalctl -xeu aspire-dashboard.service
```

### The dashboard shows no telemetry

**Cause:** The app is exporting to the wrong port or with the wrong protocol. A gRPC exporter must use 18889; an HTTP exporter must use 18890.

**Fix:** Check the app's exporter settings (`OTEL_EXPORTER_OTLP_ENDPOINT` and `OTEL_EXPORTER_OTLP_PROTOCOL`) and look for OTLP export errors in the app's own logs.

### Telemetry disappeared

**Cause:** The container restarted. Telemetry is stored in memory only.

**Fix:** None needed. This is expected behavior; see [Data Persistence and Backups](#data-persistence-and-backups).

---

## Security Notes

- This setup is for **local development only**.
- Anonymous access is enabled: anyone who can reach port 18888 can view all telemetry, and anyone who can reach 18889 or 18890 can send it.
- Published ports bind to all host interfaces. Block 18888–18890 at the firewall if the machine is on a shared network.
- Telemetry can contain sensitive data such as request URLs, headers, and log messages.

---

## Uninstall

There is no `uninstall.sh` for Aspire Dashboard. Remove it manually:

```bash
sudo systemctl disable --now aspire-dashboard.service
sudo rm /etc/systemd/system/aspire-dashboard.service
sudo systemctl daemon-reload
docker rm -f aspire-dashboard
sudo loginctl disable-linger aspire-dashboard
sudo userdel -r aspire-dashboard   # also deletes /opt/aspire-dashboard
```

---

## Additional Resources

- [Standalone Aspire Dashboard](https://learn.microsoft.com/dotnet/aspire/fundamentals/dashboard/standalone)
- [Aspire Dashboard configuration](https://learn.microsoft.com/dotnet/aspire/fundamentals/dashboard/configuration)
- [.NET Aspire on GitHub](https://github.com/dotnet/aspire)
- [OpenTelemetry documentation](https://opentelemetry.io/docs/)
