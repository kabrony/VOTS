import * as React from "react"

// Minimal stubs for your "Card" components:
export function Card(props: React.HTMLAttributes<HTMLDivElement>) {
  return (
    <div {...props} className={`rounded border p-3 ${props.className || ""}`}>
      {props.children}
    </div>
  )
}

export function CardHeader(props: React.HTMLAttributes<HTMLDivElement>) {
  return <div {...props} className={`border-b pb-2 mb-2 ${props.className || ""}`} />
}

export function CardTitle(props: React.HTMLAttributes<HTMLHeadingElement>) {
  return <h2 {...props} className={`font-bold text-lg ${props.className || ""}`} />
}

export function CardDescription(props: React.HTMLAttributes<HTMLParagraphElement>) {
  return <p {...props} className={`text-gray-500 text-sm ${props.className || ""}`} />
}

export function CardContent(props: React.HTMLAttributes<HTMLDivElement>) {
  return <div {...props} className={props.className || ""} />
}
