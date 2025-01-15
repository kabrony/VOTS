/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
    // If you still have a /pages or /ui folder, include them:
    "./pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./ui/**/*.{js,ts,jsx,tsx,mdx}"
  ],
  theme: {
    extend: {
      // optional: your custom color/fontextensions
    },
  },
  plugins: [],
};
