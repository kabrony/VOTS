import React from 'react';
import Link from 'next/link';

export default function Home() {
  return (
    <div style={{padding:'2rem',backgroundColor:'#222',color:'#fff',minHeight:'100vh'}}>
      <h1>VOTS Dashboard</h1>
      <p>
        Welcome! <Link href="/chat">Chat</Link> | <Link href="/dashboard">Telemetry</Link>
      </p>
    </div>
  );
}
