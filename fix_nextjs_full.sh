#!/usr/bin/env bash
################################################################################
# fix_nextjs_full.sh
#
# Purpose:
#   Provide a robust check/upgrade script for a Next.js 13+ project, ensuring:
#     - "app/" directory layout files exist (layout.tsx, page.tsx).
#     - Legacy "pages/" usage is either backed up or removed to avoid build conflicts.
#     - Dockerfile is updated with typical Next.js build commands (build + start).
#   This aims to reduce repeated errors about missing layouts, leftover pages, etc.
#
# Usage:
#   1) Place in ~/qmcs/VOTS
#   2) chmod +x fix_nextjs_full.sh
#   3) ./fix_nextjs_full.sh
#
# Then do: 
#   docker compose build --no-cache nextjs_dashboard
#   docker compose up -d nextjs_dashboard
#
# If you still see build errors, check logs:
#   docker compose logs -f nextjs_dashboard
################################################################################

set -e

DASHBOARD_DIR="nextjs_dashboard"
APP_DIR="$DASHBOARD_DIR/app"
PAGES_DIR="$DASHBOARD_DIR/pages"
PKG_FILE="$DASHBOARD_DIR/package.json"
DOCKERFILE="$DASHBOARD_DIR/Dockerfile"

echo "=== [Step 1] Checking for '$DASHBOARD_DIR' folder..."
if [ ! -d "$DASHBOARD_DIR" ]; then
  echo "[ERROR] No '$DASHBOARD_DIR' folder found in current directory. Aborting."
  exit 1
fi

echo "=== [Step 2] Checking Next.js directory structure..."

# Step 2a) If there's a 'pages/' folder, that might conflict with Next.js appDir usage
if [ -d "$PAGES_DIR" ]; then
  echo "[WARN] Found a 'pages/' directory. Next.js 13+ can conflict if you also have 'app/'."
  echo "       We'll back this up to 'pages_legacy_backup' to avoid conflicts."
  TS=$(date +%s)
  BACKUP="pages_legacy_backup_$TS"
  mv "$PAGES_DIR" "$DASHBOARD_DIR/$BACKUP"
  echo "[INFO] Moved '$PAGES_DIR' to '$DASHBOARD_DIR/$BACKUP'."
fi

# Step 2b) Ensure 'app/' exists
if [ ! -d "$APP_DIR" ]; then
  echo "[INFO] No '$APP_DIR' directory found. Creating it now..."
  mkdir -p "$APP_DIR"
fi

LAYOUT_FILE="$APP_DIR/layout.tsx"
PAGE_FILE="$APP_DIR/page.tsx"

echo "=== [Step 3] Ensuring a root layout.tsx..."

# If layout.tsx exists, we do not overwrite, but we can back up if user wants
if [ -f "$LAYOUT_FILE" ]; then
  echo "[INFO] Found an existing 'layout.tsx'. We won't overwrite it."
else
  echo "[INFO] Creating a minimal 'layout.tsx'..."
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
  echo "[INFO] Created minimal 'layout.tsx'."
fi

echo "=== [Step 4] Ensuring a default page.tsx..."

if [ -f "$PAGE_FILE" ]; then
  echo "[INFO] 'page.tsx' found. No action needed."
else
  echo "[INFO] Creating minimal 'page.tsx'..."
  cat << 'EOF' > "$PAGE_FILE"
export default function HomePage() {
  return (
    <main style={{ padding: "1rem", color:"#fff", backgroundColor:"#333" }}>
      <h1>VOTS Next.js 13 Dashboard</h1>
      <p>Default minimal page.tsx. Adjust as needed.</p>
    </main>
  );
}
EOF
  echo "[INFO] Created 'page.tsx'."
fi

echo "=== [Step 5] Checking/creating package.json..."
if [ ! -f "$PKG_FILE" ]; then
  echo "[WARN] No 'package.json' found in $DASHBOARD_DIR. Creating minimal package.json..."
  cat << 'EOF' > "$PKG_FILE"
{
  "name": "vots_dashboard",
  "version": "1.0.0",
  "scripts": {
    "dev": "next dev -p 3000",
    "build": "next build",
    "start": "next start -p 3000"
  },
  "dependencies": {
    "next": "13.4.12",
    "react": "18.2.0",
    "react-dom": "18.2.0"
  }
}
EOF
else
  echo "[INFO] Found 'package.json'. We'll trust it's correct for Next.js 13."
fi

echo "=== [Step 6] Checking/creating Dockerfile..."

if [ ! -f "$DOCKERFILE" ]; then
  echo "[WARN] No Dockerfile found in '$DASHBOARD_DIR'. Creating minimal Next.js Dockerfile..."
  cat << 'EOF' > "$DOCKERFILE"
# syntax=docker/dockerfile:1
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package info first:
COPY package.json ./
# (If you have package-lock.json or yarn.lock, you can also copy it here)
# e.g.: COPY package-lock.json ./

RUN npm install

# Copy the rest of the project
COPY . .

RUN npm run build

# Final runtime stage
FROM node:18-alpine
WORKDIR /app

COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/package.json ./package.json
EXPOSE 3000
CMD ["npm", "run", "start"]
EOF
  echo "[INFO] Created minimal Dockerfile for nextjs_dashboard."
else
  echo "[INFO] Dockerfile already exists in '$DASHBOARD_DIR'. We'll leave it as is."
fi

echo "=== [Step 7] Final instructions..."
echo "----------------------------------------------------------------"
echo " 1) If you have a package-lock.json, put it in nextjs_dashboard/ and"
echo "    edit your Dockerfile to COPY it for better build caching."
echo " 2) To rebuild nextjs_dashboard from scratch, run:"
echo "    docker compose build --no-cache nextjs_dashboard"
echo "    docker compose up -d nextjs_dashboard"
echo " 3) If you see 'port in use' or other errors, check logs with:"
echo "    docker compose logs -f nextjs_dashboard"
echo "----------------------------------------------------------------"
echo "[DONE] Next.js 13+ check/upgrade script completed."
