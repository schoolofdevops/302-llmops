# insurance_check MCP tool — Lab 13 capstone (CAP-01).
# Build context = course-code/labs/lab-13/solution/ (repo-root path is set by build script).
# So COPY paths reference tools/, guardrails/, etc. as TOP-LEVEL.
FROM python:3.11-slim
WORKDIR /app

# Python deps for both the tool AND the guardrails middleware
COPY tools/insurance_check/requirements.txt /tmp/req.txt
RUN pip install --no-cache-dir -r /tmp/req.txt

# Tool package + guardrails package
COPY tools/ tools/
COPY guardrails/ guardrails/

# Static coverage data — bake into the image (read-only, no ConfigMap needed)
COPY tools/insurance_check/insurance-coverage.json /app/insurance-coverage.json
# Also bake the blocklist (overrideable via ConfigMap mount at /etc/guardrails/blocklist.json)
COPY guardrails/blocklist.json /etc/guardrails/blocklist.json

ENV PORT=8040
ENV PYTHONPATH=/app
ENV COVERAGE_PATH=/app/insurance-coverage.json
ENV BLOCKLIST_PATH=/etc/guardrails/blocklist.json

EXPOSE 8040

CMD ["python", "-m", "tools.insurance_check.insurance_check_server"]
