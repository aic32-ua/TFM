FROM node:18-alpine AS angular-builder

WORKDIR /visor
COPY Visor/ ./
RUN npm ci && npm run build -- --configuration production

FROM python:3.10-slim

WORKDIR /app

COPY Scripts/ /app/Scripts/
COPY Server/ /app/Server/

RUN mkdir -p /app/Server/public
COPY --from=angular-builder /visor/dist/visor/browser /app/Server/public

RUN chmod +x /app/Scripts/entrypoint.sh

RUN apt-get update && apt-get install -y --no-install-recommends wget curl gnupg lsb-release podman npm postgresql postgresql-contrib python3-venv && apt-get clean

RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install scikit-learn psycopg2-binary python-dateutil

RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && apt-get install -y nodejs

RUN wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor -o /usr/share/keyrings/trivy-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/trivy-keyring.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/trivy.list \
    && apt-get update && apt-get install -y trivy

RUN cd /app/Server && npm install

EXPOSE 3000

WORKDIR /app

ENTRYPOINT ["/app/Scripts/entrypoint.sh"]

ENV CONTAINER_HOST=unix:///run/podman/podman.sock

CMD ["python3", "/app/Scripts/analisis_contenedores.py"]