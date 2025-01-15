"use client"

import React, { useState } from "react"

export default function PdfUploadPage() {
  const [pdfFile, setPdfFile] = useState<File | null>(null)
  const [docCategory, setDocCategory] = useState("")
  const [status, setStatus] = useState("")

  // Adjust synergy PDF endpoint
  const BACKEND_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:9000"

  async function handleUpload(e: React.FormEvent) {
    e.preventDefault()
    if (!pdfFile) {
      setStatus("No PDF file selected.")
      return
    }
    try {
      const formData = new FormData()
      formData.append("file", pdfFile)
      formData.append("doc_category", docCategory)

      const res = await fetch(`${BACKEND_URL}/pdf/upload_pdf`, {
        method: "POST",
        body: formData,
      })
      const data = await res.json()

      if (res.ok) {
        setStatus(`Upload success: ${JSON.stringify(data)}`)
      } else {
        setStatus(`Error: ${data.detail || data.error || JSON.stringify(data)}`)
      }
    } catch (err) {
      setStatus(`[Error: ${String(err)}]`)
    }
  }

  return (
    <main className="max-w-3xl mx-auto p-6 space-y-6">
      <h1 className="text-2xl font-bold text-orange-400">PDF Upload</h1>

      <form
        onSubmit={handleUpload}
        className="border border-gray-700 p-4 bg-black/50 rounded space-y-4"
      >
        <div>
          <label className="block text-sm text-gray-300 mb-1">Select PDF:</label>
          <input
            type="file"
            accept="application/pdf"
            onChange={(e) => {
              if (e.target.files && e.target.files.length > 0) {
                setPdfFile(e.target.files[0])
              } else {
                setPdfFile(null)
              }
            }}
            className="text-sm file:mr-4 file:py-1 file:px-2 file:rounded file:border-0 
                       file:bg-[#00ff66] file:text-black hover:file:bg-[#00c653]"
          />
        </div>
        <div>
          <label className="block text-sm text-gray-300 mb-1">Document Category (optional):</label>
          <input
            type="text"
            className="bg-gray-800 border border-gray-600 text-gray-100 px-3 py-2 rounded w-full"
            placeholder="e.g. finance"
            value={docCategory}
            onChange={(e) => setDocCategory(e.target.value)}
          />
        </div>
        <button
          className="bg-[#00ff66] text-black font-bold px-4 py-2 rounded hover:bg-[#00c653]"
        >
          Upload
        </button>
        {status && (
          <p className="mt-2 text-xs text-yellow-400 whitespace-pre-wrap">
            {status}
          </p>
        )}
      </form>

      <p className="text-sm text-gray-400">
        Return to{" "}
        <a href="/" className="underline text-blue-400">
          Home synergy
        </a>
        .
      </p>
    </main>
  )
}
