#!/bin/bash
# =============================================================
# Infraestrutura como Código: provisionamento de servidor web
# Instala o Apache, publica um site e garante que o serviço
# esteja ativo. Pode ser executado várias vezes (idempotente).
#
# Uso:
#   sudo ./provisionar_apache.sh
#   sudo SITE_URL="https://exemplo.com/site.zip" ./provisionar_apache.sh
# =============================================================

set -euo pipefail

WEB_DIR="/var/www/html"
TMP_DIR="/tmp/site_deploy"
SITE_URL="${SITE_URL:-}"   # opcional: URL de um .zip com o site

# --- Verifica se está rodando como root ----------------------
if [ "$EUID" -ne 0 ]; then
  echo "Erro: execute como root (use sudo)."
  exit 1
fi

# --- Atualiza o sistema --------------------------------------
echo "[1/5] Atualizando repositórios e pacotes..."
apt update -y
apt upgrade -y

# --- Instala os pacotes necessários --------------------------
echo "[2/5] Instalando Apache e unzip..."
apt install apache2 unzip wget -y

# --- Publica o site ------------------------------------------
echo "[3/5] Publicando o site em $WEB_DIR..."
if [ -n "$SITE_URL" ]; then
  rm -rf "$TMP_DIR"
  mkdir -p "$TMP_DIR"
  wget -q -O "$TMP_DIR/site.zip" "$SITE_URL"
  unzip -o -q "$TMP_DIR/site.zip" -d "$TMP_DIR"
  # Se o zip tiver uma pasta única, entra nela
  if [ "$(ls -1 "$TMP_DIR" | grep -vc '^site.zip$')" -eq 1 ]; then
    SRC="$TMP_DIR/$(ls -1 "$TMP_DIR" | grep -v '^site.zip$')"
  else
    SRC="$TMP_DIR"
  fi
  cp -r "$SRC"/. "$WEB_DIR"/
  rm -f "$WEB_DIR/site.zip"
  rm -rf "$TMP_DIR"
else
  cat > "$WEB_DIR/index.html" <<'EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <title>Servidor Web provisionado via IaC</title>
</head>
<body>
  <h1>Servidor Apache provisionado com sucesso!</h1>
  <p>Este site foi publicado automaticamente por um script Bash.</p>
</body>
</html>
EOF
fi

# --- Ajusta dono e permissões --------------------------------
echo "[4/5] Ajustando permissões..."
chown -R www-data:www-data "$WEB_DIR"
find "$WEB_DIR" -type d -exec chmod 755 {} \;
find "$WEB_DIR" -type f -exec chmod 644 {} \;

# --- Habilita e inicia o serviço -----------------------------
echo "[5/5] Habilitando e iniciando o Apache..."
systemctl enable apache2
systemctl restart apache2

echo
echo "Concluído! Status do serviço:"
systemctl is-active apache2
echo "Acesse: http://$(hostname -I | awk '{print $1}')/"
echo "Na AWS, libere a porta 80 (HTTP) no Security Group."
