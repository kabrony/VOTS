"use client";

import React, { useState, useEffect, useCallback } from "react";
import { io } from "socket.io-client";

// If your synergy agent runs at :9000, adjust if needed.
const BACKEND_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:9000";

export default function Dashboard() {
  // === Synergy Chat States ===
  const [message, setMessage] = useState("");
  const [chatHistory, setChatHistory] = useState([
    { role: "assistant", content: "Welcome to synergy chat with PDF ingestion." }
  ]);

  // === PDF Upload States ===
  const [pdfFile, setPdfFile] = useState<File | null>(null);
  const [docCategory, setDocCategory] = useState("");
  const [uploadStatus, setUploadStatus] = useState("");

  // === On mount, connect to synergy backend (socket.io) ===
  useEffect(() => {
    const socket = io(BACKEND_URL, { transports: ["websocket"] });
    socket.on("connect", () => {
      console.log("Socket connected to synergy agent!");
    });
    // Example synergy event
    socket.on("synergy-event", (data) => {
      setChatHistory(prev => [...prev, { role: "assistant", content: data }]);
    });
    return () => {
      socket.disconnect();
    };
  }, []);

  // === Synergy Chat: handle "Send" ===
  const handleSend = useCallback(() => {
    if (!message.trim()) return;
    // Add user message
    setChatHistory(prev => [...prev, { role: "user", content: message }]);
    // If you want to do HTTP or socket calls to synergy, do it here.
    // For now, we just push the user message locally.
    setMessage("");
  }, [message]);

  // === PDF Upload: handle PDF submission ===
  const handlePdfUpload = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!pdfFile) {
      setUploadStatus("Please select a PDF file first.");
      return;
    }
    try {
      const formData = new FormData();
      formData.append("file", pdfFile);
      if (docCategory) formData.append("doc_category", docCategory);

      // POST to your python_agent at /pdf/upload_pdf
      const res = await fetch(`${BACKEND_URL}/pdf/upload_pdf`, {
        method: "POST",
        body: formData,
      });
      const data = await res.json();
      if (res.ok) {
        setUploadStatus(`Upload success: ${data.message || JSON.stringify(data)}`);
      } else {
        setUploadStatus(`Upload error: ${data.detail || data.error || JSON.stringify(data)}`);
      }
    } catch (err) {
      console.error(err);
      setUploadStatus("Upload failed. Check console logs.");
    }
  };

  return (
    <div className="min-h-screen bg-black text-gray-100 p-4 flex flex-col space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-green-400">Synergy Dashboard</h1>
        <p className="text-red-500 text-sm font-semibold">
          Experimental – LLM usage has cost; synergy logs used for advanced improvements.
        </p>
      </div>

      {/* Container: chat & PDF upload side-by-side on desktop */}
      <div className="flex flex-col md:flex-row gap-6">
        {/* Left: synergy chat */}
        <div className="flex-1 bg-[#0e0e0e] border border-gray-700 rounded p-4 flex flex-col">
          <h2 className="text-orange-400 font-bold text-lg mb-2">Synergy Chat</h2>

          <div className="overflow-y-auto bg-black/20 rounded p-3 flex-1 mb-4 font-mono">
            {chatHistory.map((msg, i) => (
              <div
                key={i}
                className={`mb-2 whitespace-pre-wrap ${msg.role === "user" ? "text-orange-400" : "text-green-400"}`}
              >
                <span className="text-gray-500 mr-1">{msg.role === "user" ? ">" : "#"}</span>
                {msg.content}
              </div>
            ))}
          </div>

          <div className="flex space-x-2">
            <input
              type="text"
              className="flex-1 bg-black/50 border border-gray-600 rounded px-3 py-2 text-gray-100 font-mono focus:outline-none focus:border-orange-500"
              placeholder="Type synergy message..."
              value={message}
              onChange={(e) => setMessage(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && handleSend()}
            />
            <button
              onClick={handleSend}
              className="bg-orange-500 text-black px-4 py-2 rounded font-bold hover:bg-orange-400"
            >
              Send
            </button>
          </div>
        </div>

        {/* Right: PDF Upload */}
        <div className="w-full md:w-1/3 bg-[#0e0e0e] border border-gray-700 rounded p-4">
          <h2 className="text-blue-400 font-bold text-lg mb-2">Upload PDF</h2>
          <form onSubmit={handlePdfUpload} className="space-y-3">
            <div>
              <label className="block text-sm mb-1">Select PDF:</label>
              <input
                type="file"
                accept="application/pdf"
                onChange={(e) => {
                  if (e.target.files && e.target.files.length > 0) {
                    setPdfFile(e.target.files[0]);
                  } else {
                    setPdfFile(null);
                  }
                }}
                className="text-sm text-gray-300"
              />
            </div>
            <div>
              <label className="block text-sm mb-1">Document Category (optional):</label>
              <input
                type="text"
                className="bg-black/50 border border-gray-600 rounded px-2 py-1 text-gray-100 w-full"
                placeholder="e.g. finance, legal..."
                value={docCategory}
                onChange={(e) => setDocCategory(e.target.value)}
              />
            </div>
            <button
              type="submit"
              className="bg-[#00ff66] text-black px-4 py-2 rounded font-bold hover:bg-[#00c653]"
            >
              Upload
            </button>
          </form>
          {uploadStatus && (
            <p className="mt-3 text-xs text-yellow-400 whitespace-pre-wrap">{uploadStatus}</p>
          )}
        </div>
      </div>
    </div>
  );
}
