#!/usr/bin/env bash
set -e

# 1) Create or overwrite the main landing page at nextjs_dashboard/app/page.tsx
#    This page includes a stylized heading for "VOTS // DystoLabs," a matrixy vibe,
#    a bar chart from "recharts," and a mobile-friendly layout.

mkdir -p nextjs_dashboard/app
cat << 'PAGETSX' > nextjs_dashboard/app/page.tsx
"use client";

import React, { useState } from "react";
import { BarChart, Bar, CartesianGrid, XAxis, YAxis } from "recharts";

// Optional UI libs if you have them, adjust as needed
// If you don't have these, remove or adapt them accordingly.
import {
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
  CardContent,
} from "@/components/ui/card"; // e.g. from a custom library
import { cn } from "@/lib/utils"; // your tailwind-merge + clsx helper if you have it

// Sample data
const sampleData = [
  { day: "Mon", visitors: 230 },
  { day: "Tue", visitors: 410 },
  { day: "Wed", visitors: 180 },
  { day: "Thu", visitors: 350 },
  { day: "Fri", visitors: 290 },
  { day: "Sat", visitors: 480 },
  { day: "Sun", visitors: 320 },
];

export default function HomePage() {
  const [hoverIndex, setHoverIndex] = useState<number | null>(null);

  return (
    <main className="min-h-screen w-full bg-black text-gray-100 px-4 py-6 sm:px-6 lg:px-8">
      {/* === Heading / Hero Section === */}
      <header className="mt-4 mb-8 text-center">
        <h1 className="text-4xl sm:text-5xl font-extrabold tracking-widest text-[#00ff66] drop-shadow-lg">
          VOTS // DystoLabs
        </h1>
        <p className="mt-2 text-red-400 text-sm sm:text-base italic">
          Experimental synergy. Each LLM usage may incur cost. Built for advanced AGI synergy.
        </p>
        <p className="mt-1 text-xs text-gray-500">
          [Matrix + VSCode vibe, mobile-friendly]
        </p>
      </header>

      {/* === Main Card / Dashboard Section === */}
      <div className="mx-auto max-w-4xl">
        <Card className="border border-[#00ff66]/20 bg-black/70 shadow-lg">
          <CardHeader className="pb-0">
            <CardTitle className="font-mono text-orange-400 flex items-center">
              <span className="mr-2">■</span> Synergy Analytics
            </CardTitle>
            <CardDescription className="text-sm text-gray-400">
              Weekly Visitors
            </CardDescription>
          </CardHeader>
          <CardContent className="grid gap-4 mt-2">
            <div className="overflow-x-auto w-full h-[300px] bg-black/50 rounded-lg p-2 sm:p-4">
              <BarChart
                width={500}
                height={250}
                data={sampleData}
                onMouseMove={(state) => {
                  if (state.isTooltipActive && state.activeTooltipIndex != null) {
                    setHoverIndex(state.activeTooltipIndex);
                  } else {
                    setHoverIndex(null);
                  }
                }}
              >
                <CartesianGrid stroke="#333" strokeDasharray="3 3" />
                <XAxis dataKey="day" stroke="#666" />
                <YAxis stroke="#666" />
                <Bar
                  dataKey="visitors"
                  fill="#00ff66"
                  radius={[4, 4, 0, 0]}
                  className="transition-all duration-200"
                />
              </BarChart>
            </div>
            {hoverIndex !== null && (
              <div className="text-center text-sm text-gray-200">
                Hovering over: <span className="text-green-400">{sampleData[hoverIndex].day}</span>{" "}
                with <span className="text-green-400">{sampleData[hoverIndex].visitors}</span> visitors
              </div>
            )}
          </CardContent>
        </Card>
      </div>

      {/* === Footer === */}
      <footer className="mt-10 text-center text-xs text-gray-500">
        <p>
          &copy; {new Date().getFullYear()} VOTS // DystoLabs. 
          <span className="ml-2 text-[#00ff66]">Neon Green. Orange. Red. Black. White. Let&#39;s go!</span>
        </p>
      </footer>
    </main>
  );
}
PAGETSX

echo "[STEP 1] => Created/overwrote nextjs_dashboard/app/page.tsx"

# 2) Ensure needed packages are installed:
#    - 'recharts' for the bar chart
#    - 'tailwind-merge' (if you're using custom merging)
#    - or any other libs you need for your UI components
cd nextjs_dashboard

echo "[STEP 2] => Installing dependencies (recharts, tailwind-merge, etc.)..."
npm install recharts tailwind-merge --save

# 3) Build the Docker image (assuming you have a Dockerfile here in nextjs_dashboard)
echo "[STEP 3] => Building Docker image 'vots-nextjs' with no cache..."
docker build --no-cache -t vots-nextjs .

# 4) Stop and remove any existing container named 'vots-nextjs-container' to avoid conflicts
docker rm -f vots-nextjs-container 2>/dev/null || true

# 5) Run the container
#    Mapping host's 3001 => container's 3000
echo "[STEP 4] => Running container 'vots-nextjs-container' on port 3001..."
docker run -d \
  --name vots-nextjs-container \
  -p 3001:3000 \
  vots-nextjs

echo "[DONE] => Container is up. Visit http://<server-ip>:3001"

