import React, { useState } from 'react';

export default function ChatPage() {
  const [input, setInput] = useState("");
  const [resp, setResp] = useState("");

  const sendMessage = async () => {
    try {
      // Real usage => call a route on python_agent
      const res = await fetch("http://localhost:9000/some_chat_route"); 
      const data = await res.json();
      setResp(JSON.stringify(data));
    } catch(e) {
      setResp("Error contacting python_agent");
    }
  };

  return (
    <div style={{padding:'2rem',backgroundColor:'#333',color:'#fff',minHeight:'100vh'}}>
      <h2>Chat with Python Agent</h2>
      <div style={{marginBottom:'1rem'}}>
        <input
          style={{width:'300px', marginRight:'1rem'}}
          value={input}
          onChange={(e) => setInput(e.target.value)}
        />
        <button onClick={sendMessage}>Send</button>
      </div>
      <p>Response: {resp}</p>
    </div>
  );
}
