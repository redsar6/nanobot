FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim

# Install Node.js 20 for the WhatsApp bridge
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl ca-certificates gnupg git bubblewrap openssh-client && \
    mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" > /etc/apt/sources.list.d/nodesource.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends nodejs && \
    apt-get purge -y gnupg && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python dependencies first (cached layer)
COPY pyproject.toml README.md LICENSE ./
RUN mkdir -p nanobot bridge && touch nanobot/__init__.py && \
    uv pip install --system --no-cache . && \
    rm -rf nanobot bridge

# Copy the full source and install
COPY nanobot/ nanobot/
COPY bridge/ bridge/
RUN uv pip install --system --no-cache .

# Build the WhatsApp bridge
WORKDIR /app/bridge
RUN git config --global --add url."https://github.com/".insteadOf ssh://git@github.com/ && \
    git config --global --add url."https://github.com/".insteadOf git@github.com: && \
    npm install && npm run build
WORKDIR /app

# Create non-root user and config directory
RUN useradd -m -u 1000 -s /bin/bash nanobot && \
    mkdir -p /home/nanobot/.nanobot && \
    chown -R nanobot:nanobot /home/nanobot /app

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER nanobot
ENV HOME=/home/nanobot

# Gateway default port
EXPOSE 18790

ENTRYPOINT ["entrypoint.sh"]
CMD ["status"]

#!/bin/bash
set -e

# Crear directorio de trabajo
mkdir -p /tmp/.nanobot

# Escribir config de nanobot
if [ -n "$NANOBOT_CONFIG" ]; then
    printf '%s' "$NANOBOT_CONFIG" > /tmp/.nanobot/config.json
fi

# Escribir credenciales de Google Sheets
cat > /tmp/gsheets-key.json << 'ENDKEY'
{
  "type": "service_account",
  "project_id": "acquired-talent-492103-b7",
  "private_key_id": "0c6398c3d6fa2af9c5bf06a990c59889e500b396",
  "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDhorfPCU4Ma5K9\nxnPpIZk95YFcDQ6AWPFy5xxf52zgYHU7CTSVkVihswpj6QIJU623IgqKX7uBL3aL\nTWa+E1ZdZm4Va+h9TOxcR0QvqG8F1q8bvl1i77J7KhF7QXbmewxzBkOOlQF3QCYJ\nu3gk5d5yTl2SP4DNCfcRyAvbN5Dn0HTD5AhDWb4Z291s6OE7/pEtmzfWCzeCO2lR\n2d4v2FrvTE0TsV/TIvjrzmNqlvk3Hu1vS4H1rwxl99THeL1zCUFOD33s+JmQgWPD\nLJAskKj5Jv/xf6G3FII73Xk/fsynjvEp8plWHY1KzajAe0HcQS3rnB6HZCYdACnK\nhe18q1aNAgMBAAECggEALZYTNlJOMT6zn0FezjliTUnW3JrrtN0jbQBJ8ItgaSW7\n0aFevSAoLMUwQnbDWVCNboxDXmkQiD1nYSYSbbEY+BZXg97xEg2uTEd+vHU2dxLE\nfqGzmudMI0ugzAryI4c1QPEBSaeLrATrGnjEgYnqqyPvjjpjwqkygGZvFMtxbJAF\nRQJcBhSDWsZ2EmiZqGGADNwHuyY2n08PGoFkOYzpnZpDT3B5EXt/h7bhl7gt7xgG\nxE6Sel7m48xKn+9HuFlhschV6GKH745gkLOOMKSKZw5idc/39yJrkAMeRFFyImyf\n2TYdVi8ojbt4c33IguK4+dh7DVDEnJTaL4ULeYaGaQKBgQDySp80BBBJ5smoSlCZ\ns+4ipqPvoa0Nr3IhOPUESZ6hWTq6NyPr2B9OG2bUCoY8znhRvcTY+NN8nGv91hPI\nICCSnEzvGngjLc3MjrITU51J6fU0z6JIux1y1rvSo6n6SytFg6xVZDcUTe0PkhrG\njwW15ck9op7pDG13xtEtQhQ3GQKBgQDuZtm58u9s20hdohxOkcz+xeqt4AXyEphv\nci84gzoEPsCviP+6XiPGv3qmyrtlfcAFWoFy5/WsIJ/MhHUVvDh6ldwuiI8j/uvK\n//vPz85SOXBqtCdfge8v8hCi2De/ECANqHNGTYGNiZJ9QOn1MjBW/mK/I9UlrtCe\nKSH5m1MNlQKBgGZCcGb3wBgwu7O3icUVV9BwHIiq5+r6vWSgMWkZ2UWn701gsFx9\n3tiMYB3mQzmuusFlIougmUHikwGTNM4mIRk/tojD1yih0FYhc68MfzoO8FrVt1yS\n/J7XWnZQdREaYKz6IeX4YfbD3OXReFONUY+v5/uHgyJBCIKg+u/rD7UhAoGBAMoR\nmUh4dqIA98SNjIq4IFZucS0xrjhxtIz57rZq3DkO64mdiIxyEMb8M7y+J7qtrJ2d\nCg3YOK7N9ESInSlwITseXMOAcjtjbn7hHJIXJF0jXHrE+n6EhrVP6vPsasviohiR\niCu1tDLAwc6yv9tZ0Alck1xJxferxh3Y5XhJREtFAoGAZv/kkwPFNkuOUU3VsoBW\ndyhaH+Rq4sLMZuh2DWFB0XL7AgUtnIfK4CB0qXgQhn+zJo0qsP9y6CtTlrHauP+T\nQ/B1BBEcDgR0RhYP+dknsPHByEUVeGpF7p1c+uxXWM5fXIfXnf1iupq91pZBkogG\nUKfVIfMKLGAoCkdcS8bqzeM=\n-----END PRIVATE KEY-----\n",
  "client_email": "stydur-engage@acquired-talent-492103-b7.iam.gserviceaccount.com",
  "client_id": "106814211305812254053",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/stydur-engage%40acquired-talent-492103-b7.iam.gserviceaccount.com",
  "universe_domain": "googleapis.com"
}
ENDKEY

export GOOGLE_APPLICATION_CREDENTIALS=/tmp/gsheets-key.json
export HOME=/tmp
export NANOBOT_HOME=/tmp/.nanobot

# Instalar dependencias de Google Sheets
pip install google-auth google-api-python-client -q --break-system-packages 2>/dev/null || true

# Crear script de Google Sheets
cat > /tmp/sheets.py << 'ENDSCRIPT'
import sys, json
from google.oauth2 import service_account
from googleapiclient.discovery import build

SPREADSHEET_ID = "1LB9AJ0AY9TZWwPNv5HozbUrJNZhxAU9WH27Qmf9ST6g"
SCOPES = ["https://www.googleapis.com/auth/spreadsheets"]

def get_service():
    creds = service_account.Credentials.from_service_account_file(
        "/tmp/gsheets-key.json", scopes=SCOPES)
    return build("sheets", "v4", credentials=creds).spreadsheets()

def leer(rango):
    return get_service().values().get(
        spreadsheetId=SPREADSHEET_ID, range=rango).execute().get("values", [])

def escribir(rango, valores):
    get_service().values().update(
        spreadsheetId=SPREADSHEET_ID, range=rango,
        valueInputOption="RAW", body={"values": valores}).execute()

def agregar(hoja, valores):
    get_service().values().append(
        spreadsheetId=SPREADSHEET_ID, range=f"{hoja}!A1",
        valueInputOption="RAW", insertDataOption="INSERT_ROWS",
        body={"values": valores}).execute()

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "test"
    if cmd == "test":
        print(json.dumps(leer("Personas_Activas!A1:D10")))
    elif cmd == "leer":
        print(json.dumps(leer(sys.argv[2])))
    elif cmd == "escribir":
        escribir(sys.argv[2], json.loads(sys.argv[3]))
        print("OK")
    elif cmd == "agregar":
        agregar(sys.argv[2], json.loads(sys.argv[3]))
        print("OK")
ENDSCRIPT

exec entrypoint.sh "$@"
