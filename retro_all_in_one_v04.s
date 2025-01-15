cat << 'EOF' > retro_all_in_one_v04.sh
#!/usr/bin/env bash
set -e

###############################################################################
# 1) Confirm "nextjs_dashboard" folder existence
###############################################################################
if [ ! -d "nextjs_dashboard" ]; then
  echo "ERROR: 'nextjs_dashboard' folder not found. Aborting."
  exit 1
fi

echo "==============================================================================="
echo "Overwriting 'app/page.tsx' for a single-page synergy, mostly black & green..."
echo "==============================================================================="

mkdir -p nextjs_dashboard/app

###############################################################################
# 2) The main Page
###############################################################################
cat << 'PAGE_EOF' > nextjs_dashboard/app/page.tsx
"use client";

import React, { useState, useEffect, useCallback } from "react";
import { useDropzone } from "react-dropzone";
import { format } from "date-fns";
import { Bar, BarChart, CartesianGrid, ResponsiveContainer, Tooltip as ReTooltip, XAxis, YAxis } from "recharts";

/*******************************************************************************
 * Hook for typewriter effect
 ******************************************************************************/
function useTypewriter(text: string, speed = 40) {
  const [typed, setTyped] = useState("");

  useEffect(() => {
    let i = 0;
    const timer = setInterval(() => {
      if (i < text.length) {
        setTyped((prev) => prev + text.charAt(i));
        i++;
      } else {
        clearInterval(timer);
      }
    }, speed);

    return () => clearInterval(timer);
  }, [text, speed]);

  return typed;
}

function RetroTyped({
  children,
  speed = 40,
}: {
  children: string;
  speed?: number;
}) {
  const typed = useTypewriter(children, speed);
  return (
    <span className="font-mono">
      {typed}
      <span className="animate-pulse">_</span>
    </span>
  );
}

/*******************************************************************************
 * Minimal color usage, mostly black/green/white, minor accent
 ******************************************************************************/
const palette = {
  green: "#00ff66",
  black: "#000000",
  white: "#ffffff",
  accent: "#ff3b3b", // a bit of red accent
};

/*******************************************************************************
 * Shared Panel
 ******************************************************************************/
function Panel({
  title,
  type = "module",
  children,
}: {
  title: string;
  type?: string;
  children: React.ReactNode;
}) {
  return (
    <div
      className="relative bg-black/90 rounded border border-green-500/30 shadow-lg overflow-hidden"
      style={{
        boxShadow: "0 0 20px rgba(0, 255, 102, 0.15)",
      }}
    >
      <div className="p-3 border-b border-green-500/20 flex items-center justify-between bg-black/70 select-none">
        <h2 className="text-green-400 font-bold text-lg">
          <RetroTyped speed={50}>{title}</RetroTyped>
        </h2>
        <span className="text-xs text-green-300/70 uppercase tracking-wider">
          <RetroTyped speed={50}>{type}</RetroTyped>
        </span>
      </div>
      <div className="p-4">{children}</div>
    </div>
  );
}

/*******************************************************************************
 * 1) Synergy Chat
 ******************************************************************************/
function SynergyChat() {
  const [message, setMessage] = useState("");
  const [chatHistory, setChatHistory] = useState([
    { role: "system", content: "CORE v4.0 INIT" },
    { role: "assistant", content: "WELCOME to synergy matrix..." },
  ]);

  const executeMsg = () => {
    if (!message.trim()) return;
    const userMsg = { role: "user", content: message };
    const assistantReply = {
      role: "assistant",
      content: "EXECUTING => " + message.toUpperCase(),
    };
    setChatHistory((prev) => [...prev, userMsg, assistantReply]);
    setMessage("");
  };

  return (
    <div className="flex flex-col gap-2 h-[300px]">
      <div className="flex-1 overflow-y-auto bg-black/80 rounded p-3 border border-green-500/30">
        {chatHistory.map((msg, idx) => {
          let colorClass = "text-gray-200";
          if (msg.role === "system") colorClass = "text-green-400";
          if (msg.role === "assistant") colorClass = "text-green-300";
          if (msg.role === "user") colorClass = "text-accent"; // red accent

          return (
            <div key={idx} className={`mb-1 ${colorClass}`}>
              <span className="text-gray-500 mr-2">
                {msg.role === "user" ? ">" : "#"}
              </span>
              <RetroTyped speed={25}>{msg.content}</RetroTyped>
            </div>
          );
        })}
      </div>
      <div className="flex gap-2">
        <input
          className="flex-1 bg-black/80 border border-green-600 px-3 py-1.5 rounded text-green-100 focus:outline-none"
          value={message}
          onChange={(e) => setMessage(e.target.value)}
          placeholder="Enter synergy command..."
          onKeyDown={(e) => {
            if (e.key === "Enter") executeMsg();
          }}
        />
        <button
          onClick={executeMsg}
          className="px-4 py-1.5 border border-green-500 text-green-400 bg-black/80 rounded hover:bg-black/60"
        >
          <RetroTyped speed={25}>Execute</RetroTyped>
        </button>
      </div>
    </div>
  );
}

/*******************************************************************************
 * 2) PDF Upload
 ******************************************************************************/
function PdfUpload() {
  const [uploadStatus, setUploadStatus] = useState("");

  const onDrop = useCallback((files: File[]) => {
    if (!files.length) return;
    const pdf = files[0];
    setUploadStatus(`PDF: ${pdf.name}\n(placeholder: no real backend)`);
  }, []);

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    onDrop,
    multiple: false,
    accept: { "application/pdf": [".pdf"] },
  });

  return (
    <div className="flex flex-col gap-2">
      <div
        {...getRootProps()}
        className={`border-2 border-dashed rounded p-4 text-center cursor-pointer transition ${
          isDragActive ? "border-green-500" : "border-green-800"
        }`}
      >
        <input {...getInputProps()} />
        {isDragActive ? (
          <p className="text-green-400">Drop your PDF here...</p>
        ) : (
          <p className="text-gray-300">
            <RetroTyped speed={30}>Drag or click to select a PDF</RetroTyped>
          </p>
        )}
      </div>
      <pre className="text-green-300 text-sm whitespace-pre-wrap min-h-[40px]">
        {uploadStatus}
      </pre>
    </div>
  );
}

/*******************************************************************************
 * 3) Agent Blog
 ******************************************************************************/
function AgentBlog() {
  const date = format(new Date(), "MMM dd, yyyy");
  const lines = [
    "Daily synergy agent log:",
    "1) Consolidated UI into single page with black & green palette.",
    "2) Minimal accent usage (red, lightly).",
    "3) Telemetry & PDF placeholders ready.",
  ];

  return (
    <div className="bg-black/80 border border-green-500/30 p-3 rounded">
      <p className="text-green-400 text-xs mb-2">
        <RetroTyped speed={25}>{`${date} :: Agent Insights`}</RetroTyped>
      </p>
      {lines.map((line, i) => (
        <p className="text-gray-200 text-sm" key={i}>
          <RetroTyped speed={25}>{line}</RetroTyped>
        </p>
      ))}
    </div>
  );
}

/*******************************************************************************
 * 4) Telemetry
 ******************************************************************************/
const sampleData = [
  { day: "Mon", cpu: 42, mem: 60 },
  { day: "Tue", cpu: 50, mem: 65 },
  { day: "Wed", cpu: 57, mem: 70 },
  { day: "Thu", cpu: 61, mem: 72 },
  { day: "Fri", cpu: 73, mem: 80 },
  { day: "Sat", cpu: 38, mem: 45 },
  { day: "Sun", cpu: 31, mem: 40 },
];

function Telemetry() {
  return (
    <div className="w-full h-[250px] bg-black/80 border border-green-500/30 rounded">
      <ResponsiveContainer width="100%" height="100%">
        <BarChart data={sampleData}>
          <CartesianGrid strokeDasharray="2 2" stroke="#555" />
          <XAxis dataKey="day" stroke="#ccc" />
          <YAxis stroke="#ccc" />
          <ReTooltip
            contentStyle={{ backgroundColor: "#222", border: "1px solid #666" }}
          />
          <Bar dataKey="cpu" fill="#00ff66" />
          <Bar dataKey="mem" fill="#ff3b3b" />
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
}

/*******************************************************************************
 * MAIN - Single Page
 ******************************************************************************/
export default function RetroAllInOneV04() {
  const instructions = [
    "DRAG HEADERS TO REARRANGE (if using drag libs).",
    "ALL MODULES TIE INTO SYNERGY CORE.",
    "TYPE ANY COMMANDS IN INTERFACE.",
  ];

  const moduleStates = {
    chat: "online",
    pdf: "standby",
    blog: "synced",
    telemetry: "active",
  };

  return (
    <main className="min-h-screen bg-black text-gray-200 font-mono p-4 relative">
      <header className="mb-6 pb-4 border-b border-green-700/40">
        <div className="flex items-center gap-3 mb-4">
          <h1 className="text-3xl font-bold tracking-wide text-green-400">
            <RetroTyped speed={35}>VOTS // DYSTOLABS</RetroTyped>
          </h1>
          <span className="text-green-600 text-sm animate-pulse">v4.0</span>
        </div>
        <div className="bg-black/80 border border-green-500/30 rounded p-3">
          <h2 className="text-green-300 font-bold mb-3 text-sm">
            <RetroTyped>MATRIX PROTOCOL INIT</RetroTyped>
          </h2>
          <ul className="text-xs space-y-1">
            {instructions.map((inst, i) => (
              <li key={i} className="ml-3">
                <span className="text-green-400">➜</span>{" "}
                <RetroTyped>{inst}</RetroTyped>
              </li>
            ))}
          </ul>
          <div className="mt-3 grid grid-cols-2 md:grid-cols-4 gap-2 text-xs">
            {Object.entries(moduleStates).map(([mod, status]) => (
              <div
                key={mod}
                className="bg-black/60 p-1.5 border border-green-800 rounded"
              >
                <RetroTyped speed={40}>
                  {mod.toUpperCase()}: {status.toUpperCase()}
                </RetroTyped>
              </div>
            ))}
          </div>
        </div>
      </header>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* Chat */}
        <Panel title="Interface_" type="chat">
          <SynergyChat />
        </Panel>

        {/* PDF */}
        <Panel title="PDF Upload_" type="pdf">
          <PdfUpload />
        </Panel>

        {/* Blog */}
        <Panel title="Agent Blog_" type="blog">
          <AgentBlog />
        </Panel>

        {/* Telemetry */}
        <Panel title="Telemetry_" type="telemetry">
          <Telemetry />
        </Panel>
      </div>

      <footer className="mt-4 pt-4 border-t border-green-500/30 text-center text-xs">
        <RetroTyped speed={50}>
          SYNERGY PAGE :: {new Date().getFullYear()} :: ALL SYSTEMS GO
        </RetroTyped>
      </footer>
    </main>
  );
}
PAGE_EOF

echo "Wrote 'nextjs_dashboard/app/page.tsx' (v0.04)."

###############################################################################
# 3) Provide minimal "retro_text.tsx" placeholder if needed
###############################################################################
cat << 'RETRO_TEXT_EOF' > nextjs_dashboard/app/retro_text.tsx
"use client";

/* This is a minimal placeholder if Next.js tries to import from retro_text.
   In v0.04, we do the typed logic inline. So here's just a dummy. */
import React from "react";
export default function RetroText({ children }: { children: React.ReactNode }) {
  return <span>{children}</span>;
}
RETRO_TEXT_EOF

echo "Wrote 'retro_text.tsx' placeholder."

###############################################################################
# 4) Minimal "globals.css" for black backgrounds, etc.
###############################################################################
cat << 'CSS_EOF' > nextjs_dashboard/app/globals.css
/* Minimal global CSS for black background, green text, etc. */
html, body {
  margin: 0;
  padding: 0;
  background: #000;
  color: #eee;
  font-family: monospace, Courier, sans-serif;
}

::-webkit-scrollbar {
  width: 6px;
  background-color: #111;
}
::-webkit-scrollbar-thumb {
  background-color: #555;
}
CSS_EOF

echo "Wrote 'globals.css'."

###############################################################################
# 5) Dockerfile
###############################################################################
cat << 'DOCKERFILE_EOF' > nextjs_dashboard/Dockerfile
# syntax=docker/dockerfile:1
FROM node:18-alpine as builder
WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . ./
RUN npm run build

FROM node:18-alpine
WORKDIR /app

COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/package*.json ./

RUN npm install --production

EXPOSE 3000
CMD ["npm", "run", "start"]
DOCKERFILE_EOF

echo "Wrote 'nextjs_dashboard/Dockerfile'."

###############################################################################
# 6) Install needed deps + build Docker
###############################################################################
cd nextjs_dashboard

echo "Installing extra deps: react-dropzone, date-fns, recharts..."
npm install react-dropzone date-fns recharts

echo "Building Docker image 'retro_v04' (no cache)..."
docker build --no-cache -t retro_v04 .

echo "Stopping old container if exists..."
docker rm -f retro_v04_container 2>/dev/null || true

echo "Running 'retro_v04_container' on port 3001 => container:3000"
docker run -d --name retro_v04_container -p 3001:3000 retro_v04

cd ..

echo ""
echo "========================================================="
echo "Retro synergy single-page v0.04 is now running on port 3001."
echo "Open http://<server-ip>:3001 to see black/green synergy!"
echo "========================================================="
EOF

chmod +x retro_all_in_one_v04.sh

echo ""
echo "Done! Use './retro_all_in_one_v04.sh' to build & run the synergy single-page (v0.04)."
echo "It overwrites 'nextjs_dashboard/app/page.tsx' + Docker build => port 3001."
