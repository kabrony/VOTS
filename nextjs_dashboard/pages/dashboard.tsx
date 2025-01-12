import React, { useEffect, useState } from 'react';

export default function Dashboard() {
  const [data, setData] = useState<any>({});

  useEffect(() => {
    const fetchData = async() => {
      try {
        // call /telemetry on python_agent
        const res = await fetch("http://localhost:9000/telemetry");
        const json = await res.json();
        setData(json);
      } catch(e) {
        console.error("Telemetry fetch error:", e);
      }
    };
    fetchData();
  }, []);

  return (
    <div style={{padding:'2rem', backgroundColor:'#444', color:'#fff', minHeight:'100vh'}}>
      <h1>VOTS Telemetry Dashboard</h1>
      <pre>{JSON.stringify(data, null, 2)}</pre>
    </div>
  );
}
