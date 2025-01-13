/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  env: {
    // Expose only the keys you need on the client side!
    // If these are sensitive, keep them on server side or in api routes.
    NEXT_PUBLIC_OPENAI_API_KEY: process.env.OPENAI_API_KEY || "",
    NEXT_PUBLIC_GEMINI_API_KEY: process.env.GEMINI_API_KEY || "",
    NEXT_PUBLIC_MONGO_URI: process.env.MONGO_URI || "",
  },
};

module.exports = nextConfig;
