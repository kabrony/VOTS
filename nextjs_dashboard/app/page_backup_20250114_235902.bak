"use client";

import React, { useState, useEffect, useCallback } from "react";
import {
  BarChart,
  Bar,
  CartesianGrid,
  XAxis,
  YAxis,
  Tooltip,
  ResponsiveContainer,
} from "recharts";

/*******************************************************************************
 * Pixelated "VOTS" Animation
 ******************************************************************************/
function PixelatedVots() {
  const textFrames = ["VOTS", ".OTS", "V.TS", "VO.S", "VOT."];
  const [frame, setFrame] = useState(0);

  useEffect(() => {
    const interval = setInterval(() => {
      setFrame((prev) => (prev + 1) % textFrames.length);
    }, 300);
    return () => clearInterval(interval);
  }, [textFrames.length]); // fix missing dependency

  return (
    <div
      className="absolute top-2 right-2 text-green-400 text-sm"
      style={{ letterSpacing: "-1px" }}
    >
      {textFrames[frame].split("").map((char, index) => (
        <span key={index} style={{ imageRendering: "pixelated" }}>
          {char}
        </span>
      ))}
    </div>
  );
}

/*******************************************************************************
 * Chat Module
 ******************************************************************************/
function ChatModule() {
  const [input, setInput] = useState("");
  const [messages, setMessages] = useState([
    { role: "system", content: "SYNERGY CORE v3.3.7: Online" },
    { role: "assistant", content: "Awaiting synergy commands..." },
  ]);

  const sendMessage = useCallback(() => {
    if (!input.trim()) return;
    setMessages((prev) => [
      ...prev,
      { role: "user", content: input },
      {
        role: "assistant",
        content: `>> EXECUTING SYNERGY: ${input.toUpperCase()}`,
      },
    ]);
    setInput("");
  }, [input]);

  return (
    <div className="flex flex-col bg-black border border-lime-500/50 rounded-md p-3 min-h-[250px] font-mono text-sm">
      <div className="flex items-center mb-2">
        <span className="text-lime-400 font-bold mr-2">{">"}</span>
        <h2 className="text-lime-400 font-bold tracking-wide">Synergy Chat</h2>
      </div>

      <div className="flex-1 overflow-y-auto space-y-1 mb-2">
        {messages.map((msg, i) => {
          let color = "text-blue-300";
          let prefix = "~";
          if (msg.role === "system") {
            color = "text-lime-400";
            prefix = "#";
          } else if (msg.role === "user") {
            color = "text-orange-400";
            prefix = ">";
          }
          return (
            <div key={i} className={color}>
              <span className="mr-1">{prefix}</span>
              {msg.content}
            </div>
          );
        })}
      </div>

      <div className="flex gap-2">
        <span className="text-gray-500">{">"}</span>
        <input
          className="flex-1 bg-transparent border-b border-lime-500/50 text-sm px-1 py-0.5 focus:outline-none text-gray-200"
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && sendMessage()}
        />
      </div>
    </div>
  );
}

/*******************************************************************************
 * PDF Ingestion Module
 ******************************************************************************/
function PdfModule() {
  const [uploadedFiles, setUploadedFiles] = useState<File[]>([]);

  const handleFiles = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (!e.target.files) return;
    const filesArr = Array.from(e.target.files);
    setUploadedFiles(filesArr);
  };

  return (
    <div className="flex flex-col bg-black border border-sky-500/50 rounded-md p-3 min-h-[250px] font-mono text-sm">
      <div className="flex items-center mb-2">
        <span className="text-sky-400 font-bold mr-2">{">"}</span>
        <h2 className="text-sky-400 font-bold tracking-wide">PDF Ingestion</h2>
      </div>

      <div className="text-xs text-gray-400 mb-2">
        <p>Upload PDF documents below:</p>
      </div>

      <input
        type="file"
        accept="application/pdf"
        multiple
        className="text-sm text-gray-300 mb-2
                   file:mr-2 file:py-0.5 file:px-2 file:border file:border-sky-500
                   file:bg-sky-700/40 file:text-sky-50 file:rounded-md
                   hover:file:bg-sky-600/40 focus:outline-none"
        onChange={handleFiles}
      />

      <ul className="list-disc list-inside text-xs mt-1 text-gray-400 space-y-1 flex-1 overflow-y-auto">
        {uploadedFiles.map((f, idx) => (
          <li key={idx}>{f.name}</li>
        ))}
      </ul>
    </div>
  );
}

/*******************************************************************************
 * Telemetry Module
 ******************************************************************************/
function TelemetryModule() {
  const [chartData] = useState([
    { name: "CPU", value: 35 },
    { name: "Memory", value: 58 },
    { name: "LLM Calls", value: 20 },
    { name: "SynergyEvt", value: 5 },
  ]);

  return (
    <div className="bg-black border border-orange-500/50 rounded-md p-3 min-h-[250px] flex flex-col font-mono text-sm">
      <div className="flex items-center mb-2">
        <span className="text-orange-400 font-bold mr-2">{">"}</span>
        <h2 className="text-orange-400 font-bold tracking-wide">
          Telemetry
        </h2>
      </div>
      <div className="text-xs text-gray-400 mb-3">
        <p>Real-time synergy stats:</p>
      </div>
      <div className="flex-1">
        <ResponsiveContainer width="100%" height="100%">
          <BarChart data={chartData}>
            <CartesianGrid strokeDasharray="3 3" stroke="#333" />
            <XAxis dataKey="name" stroke="#aaa" tickLine={false} />
            <YAxis stroke="#aaa" tickLine={false} />
            <Tooltip
              wrapperStyle={{
                backgroundColor: "#111",
                border: "1px solid #555",
                padding: "5px",
              }}
              labelStyle={{ color: "#fff" }}
              itemStyle={{ color: "#fff" }}
            />
            <Bar dataKey="value" fill="#ff8800" />
          </BarChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}

/*******************************************************************************
 * Blog Module
 ******************************************************************************/
function BlogModule() {
  const [entries] = useState([
    "Synergy pipeline updated at 09:15",
    "User 'alpha' requested LLM resources at 09:20",
    "System stable, no major alerts",
  ]);

  return (
    <div className="bg-black border border-pink-500/50 rounded-md p-3 min-h-[250px] flex flex-col font-mono text-sm">
      <div className="flex items-center mb-2">
        <span className="text-pink-400 font-bold mr-2">{">"}</span>
        <h2 className="text-pink-400 font-bold tracking-wide">Blog / Logs</h2>
      </div>
      <div className="flex-1 overflow-y-auto space-y-1 text-gray-300">
        {entries.map((line, idx) => (
          <div key={idx}>
            <span className="text-gray-500 mr-1">-</span>
            {line}
          </div>
        ))}
      </div>
    </div>
  );
}

/*******************************************************************************
 * Blueprint Doc
 ******************************************************************************/
function BlueprintModule() {
  const blueprintText = `
VOTS // DystoLabs: Enhanced Performance & Intelligence

> Performance:
  - Next.js code splitting, caching, etc.
  - Microservice optimization

> Adaptability & Modularity:
  - Decoupled modules
  - Feature flags for synergy expansions

> ML Integration:
  - RAG w/ LLM
  - Anomaly detection in telemetry

> Code Analysis:
  - "TRILOGY" agent for code QA

...(Truncated)...
`;

  return (
    <div className="bg-black border border-fuchsia-500/50 rounded-md p-3 min-h-[250px] flex flex-col font-mono text-sm">
      <div className="flex items-center mb-2">
        <span className="text-fuchsia-400 font-bold mr-2">{">"}</span>
        <h2 className="text-fuchsia-400 font-bold tracking-wide">
          Blueprint Doc
        </h2>
      </div>
      <div className="flex-1 text-gray-300 whitespace-pre-wrap overflow-y-auto leading-relaxed">
        {blueprintText}
      </div>
    </div>
  );
}

/*******************************************************************************
 * Main Single-Page synergy
 ******************************************************************************/
export default function SynergySinglePage() {
  return (
    <main
      className="relative min-h-screen text-gray-100 p-4"
      style={{
        background:
          "linear-gradient(to bottom right, #1e1e1e 65%, #111111 100%)",
      }}
    >
      <PixelatedVots />

      <header className="mb-5 px-2">
        <h1 className="text-3xl md:text-4xl font-bold text-green-400 uppercase drop-shadow-md font-mono">
          {">"} VOTS // DystoLabs
        </h1>
        <p className="text-sm text-gray-500 mt-1 font-mono">
          Single-Page Synergy Terminal
        </p>
      </header>

      <section className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-4 px-2">
        <ChatModule />
        <PdfModule />
        <TelemetryModule />
        <BlogModule />
      </section>

      <section className="mt-4 px-2">
        <BlueprintModule />
      </section>

      <footer className="mt-8 text-center text-xs text-gray-600 border-t border-gray-700/40 pt-3 font-mono px-2">
        <p className="mb-1">
          © {new Date().getFullYear()} · VOTS // DystoLabs
        </p>
        <p>// All synergy modules nominal.</p>
      </footer>
    </main>
  );
}
