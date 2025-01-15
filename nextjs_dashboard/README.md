# VOTS // Next.js Dashboard

This folder holds a **Next.js 13** front-end with synergy chat features, 
Socket.IO integration, Tailwind, and Puppeteer for advanced use cases.

## Quick Start

1. **Install** dependencies:
   \`\`\`bash
   npm install --legacy-peer-deps --force
   \`\`\`

2. **Dev** mode:
   \`\`\`bash
   npm run dev
   # open http://localhost:3000
   \`\`\`

3. **Check** lint & build:
   \`\`\`bash
   ./check_dashboard.sh
   \`\`\`
   - logs go to \`dashboard_check.log\`.

4. **Environment**:
   - If your synergy backend is at \`http://localhost:9000\`, no changes needed.
   - If in Docker Compose, set \`NEXT_PUBLIC_API_URL=http://python_agent:9000\` in \`.env\`.

## UI Layouts / External Code Integration

If you want to incorporate external React/Tailwind code (like [ui-layouts](https://github.com/naymurdev/ui-layouts)):

- **Install** dependencies from that repo (e.g. \`framer-motion\`, \`clsx\`, \`tailwind-merge\`).
- **Copy** the relevant hooks/components (File Upload, Embla Carousel, etc.) into \`components/\`.
- Import them in your Next.js pages, e.g. \`import FileUpload from '@/components/FileUpload'\`.

Example hooking up \`FileUpload\`:
\`\`\`tsx
import FileUpload from '@/components/FileUpload'

export default function SomePage() {
  return <FileUpload onFileSelected={(file) => console.log(file)} />
}
\`\`\`

## Docker Build

\`\`\`bash
docker build -t vots-dashboard .
docker run -p 3001:3000 vots-dashboard
# open http://localhost:3001
\`\`\`

## Known Warnings

- Some packages might produce deprecation messages (e.g. older versions).
- We've pinned modern versions in \`package.json\`. 
- If you still see \`ETARGET\` or \`no matching version found\`, double-check that your network or npm registry is up to date.

Enjoy your synergy-based Next.js dashboard!
