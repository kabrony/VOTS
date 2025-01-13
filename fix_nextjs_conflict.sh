#!/usr/bin/env bash
################################################################################
# fix_nextjs_conflict.sh
#
# A robust script that ensures your "nextjs_dashboard" folder has:
#   - No leftover "pages/" directory conflicting with Next.js 13 "app/" usage
#   - A minimal "public/" folder if none exist
#   - A Dockerfile that only copies "public/" if it actually exists
#   - Minimal "layout.tsx" and "page.tsx" in "app/" if missing
#
# This resolves the error:
#   "failed to compute cache key: ...: not found /app/public"
# and the leftover page conflicts from "pages/index.tsx" vs. "app/page.tsx".
################################################################################

set -e

DASHBOARD_DIR="nextjs_dashboard"
APP_DIR="$DASHBOARD_DIR/app"
PAGES_DIR="$DASHBOARD_DIR/pages"
PUBLIC_DIR="$DASHBOARD_DIR/public"
DOCKERFILE="$DASHBOARD_DIR/Dockerfile"

echo "=== [1] Checking for '$DASHBOARD_DIR'..."
if [ ! -d "$DASHBOARD_DIR" ]; then
  echo "[ERROR] No '$DASHBOARD_DIR' folder found. Aborting."
  exit 1
fi

echo "=== [2] Checking if 'pages/' directory exists (legacy Next.js)..."
if [ -d "$PAGES_DIR" ]; then
  TS=$(date +%s)
  BACKUP="pages_legacy_backup_$TS"
  echo "[WARN] Found '$PAGES_DIR'. This conflicts with app/ usage in Next.js 13."
  echo "[INFO] Moving '$PAGES_DIR' to '$DASHBOARD_DIR/$BACKUP' to prevent conflicts."
  mv "$PAGES_DIR" "$DASHBOARD_DIR/$BACKUP"
fi

echo "=== [3] Ensuring we have an 'app/' folder..."
if [ ! -d "$APP_DIR" ]; then
  mkdir -p "$APP_DIR"
  echo "[INFO] Created '$APP_DIR'."
fi

LAYOUT_FILE="$APP_DIR/layout.tsx"
PAGE_FILE="$APP_DIR/page.tsx"

if [ ! -f "$LAYOUT_FILE" ]; then
  echo "[INFO] Creating minimal 'layout.tsx' in '$APP_DIR'..."
  cat << 'EOF' > "$LAYOUT_FILE"
export const metadata = {
  title: "VOTS Next.js Dashboard",
  description: "Root layout for Next.js 13",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body style={{ margin: 0, padding: 0 }}>
        {children}
      </body>
    </html>
  );
}
EOF
else
  echo "[INFO] '$LAYOUT_FILE' exists; leaving it as is."
fi

if [ ! -f "$PAGE_FILE" ]; then
  echo "[INFO] Creating minimal 'page.tsx' in '$APP_DIR'..."
  cat << 'EOF' > "$PAGE_FILE"
export default function HomePage() {
  return (
    <main style={{ padding: "1rem", color: "#fff", backgroundColor: "#333" }}>
      <h1>VOTS Next.js 13 Dashboard</h1>
      <p>Default minimal page.tsx. Adjust as needed.</p>
    </main>
  );
}
EOF
else
  echo "[INFO] '$PAGE_FILE' exists; leaving it as is."
fi

echo "=== [4] Checking for 'public/' folder..."
if [ -d "$PUBLIC_DIR" ]; then
  echo "[INFO] 'public/' folder already exists in $DASHBOARD_DIR."
else
  echo "[INFO] 'public/' folder NOT found. Creating an empty 'public/' to avoid Docker COPY error..."
  mkdir -p "$PUBLIC_DIR"
fi

# We'll see if there's a line "COPY --from=builder /app/public ./public" in the Dockerfile
echo "=== [5] Checking Dockerfile for copying 'public/'..."

if [ -f "$DOCKERFILE" ]; then
  echo "[INFO] Dockerfile found. Will ensure it's consistent about 'public/'."
  
  # If "public" doesn't exist, some old lines might cause an error. Let's see if the user wants to remove them.
  # But we just created a 'public/' so the COPY step is fine. We'll just confirm there's a line referencing it.
  
  if grep -q "/app/public" "$DOCKERFILE"; then
    echo "[INFO] Dockerfile references '/app/public'. That's OK now that we have a 'public/' folder."
  else
    echo "[WARN] Dockerfile doesn't reference '/app/public'. If you want Next.js static assets, add a line e.g.:
COPY --from=builder /app/public ./public
"
  fi

else
  echo "[WARN] No Dockerfile in $DASHBOARD_DIR. Creating a minimal one..."

  cat << 'EOF' > "$DOCKERFILE"
# syntax=docker/dockerfile:1
FROM node:18-alpine AS builder
WORKDIR /app

COPY package.json ./
# COPY package-lock.json ./   # If you have one

RUN npm install

COPY . .

RUN npm run build

FROM node:18-alpine
WORKDIR /app

COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/package.json ./package.json

EXPOSE 3000
CMD ["npm", "run", "start"]
EOF
  echo "[INFO] Created minimal Dockerfile. References '/app/public'."
fi

echo "=== [6] Done. Please run your Docker build steps next..."

cat <<EOT
-----------------------------------------------------------------
NEXT STEPS:
  1) docker compose build --no-cache nextjs_dashboard
  2) docker compose up -d nextjs_dashboard
  3) If you see any port conflicts or logs issues:
       docker compose logs -f nextjs_dashboard
  4) If you had leftover "pages/", check the folder we renamed:
       nextjs_dashboard/pages_legacy_backup_XXXX
-----------------------------------------------------------------
EOT

echo "[DONE] fix_nextjs_conflict.sh script completed successfully."
