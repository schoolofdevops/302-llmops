"""otel_setup.py — Reusable OTEL TracerProvider for MCP tool servers.

Imported by triage_server.py / treatment_lookup_server.py / book_appointment_server.py.

NOTE on D-18 (CONTEXT.md) partial compliance:
The Hermes agent binary does NOT propagate W3C traceparent across MCP calls.
Tool spans from this setup will appear as SEPARATE ROOT TRACES in Tempo,
correlated by time window and service.name — not as children of an agent.request span.
This is documented honestly; the treatment_lookup → httpx → rag-retriever sub-tree
IS hierarchical (child span via HTTPXClientInstrumentor) and satisfies OBS-06 literally.

OTEL exporter is ENABLED only when OTEL_EXPORTER_OTLP_ENDPOINT is set non-empty.
Lab 07 (Docker Compose) sets it to "" so MCP servers don't retry-spam logs trying to
reach an in-cluster collector. Lab 09 (K8s) sets it to the OTEL Collector ClusterIP.
"""
import os
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource

OTEL_ENDPOINT = os.environ.get("OTEL_EXPORTER_OTLP_ENDPOINT", "").strip()


def setup_tracing(service_name: str):
    """Wire OTLP gRPC exporter for this service. Idempotent — safe to call once at startup.

    No-op when OTEL_EXPORTER_OTLP_ENDPOINT is empty/unset (e.g., Lab 07 Docker mode):
    the TracerProvider is still installed (so FastAPIInstrumentor / HTTPXClientInstrumentor
    don't blow up at import) but no BatchSpanProcessor is wired, so spans are dropped
    without retry noise.
    """
    resource = Resource(attributes={"service.name": service_name})
    provider = TracerProvider(resource=resource)
    if OTEL_ENDPOINT:
        exporter = OTLPSpanExporter(endpoint=OTEL_ENDPOINT, insecure=True)
        provider.add_span_processor(BatchSpanProcessor(exporter))
    trace.set_tracer_provider(provider)
    return trace.get_tracer(service_name)
