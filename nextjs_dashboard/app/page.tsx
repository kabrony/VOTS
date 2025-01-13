"use client";
import React from "react";

export default function HomePage() {
  // Sample usage of the env variables
  const openAiKey = process.env.NEXT_PUBLIC_OPENAI_API_KEY;
  const geminiKey = process.env.NEXT_PUBLIC_GEMINI_API_KEY;
  const mongoUri  = process.env.NEXT_PUBLIC_MONGO_URI;

  return (
    <div className="min-h-screen bg-gray-900 text-gray-100 flex flex-col items-center justify-center p-8">
      <h1 className="text-4xl font-bold mb-4">
        VOTS Next.js Dashboard
      </h1>
      <p className="mb-2">
        OpenAI Key: {openAiKey ? openAiKey.slice(0, 10) + "..." : "Not found"}
      </p>
      <p className="mb-2">
        Gemini Key: {geminiKey ? geminiKey.slice(0, 10) + "..." : "Not found"}
      </p>
      <p className="mb-2">
        Mongo URI: {mongoUri ? mongoUri.slice(0, 20) + "..." : "Not found"}
      </p>
      <button className="bg-blue-600 hover:bg-blue-700 px-4 py-2 rounded mt-4">
        Example Action
      </button>
    </div>
  );
}
