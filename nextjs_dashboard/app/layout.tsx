import './globals.css';
import { ReactNode } from 'react';

export const metadata = {
  title: 'VOTS // Synergy Terminal',
  description: 'Single-page synergy with Tailwind in Next.js App Router',
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body>
        {children}
      </body>
    </html>
  );
}
