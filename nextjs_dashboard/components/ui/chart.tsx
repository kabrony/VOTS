import * as React from "react"

// Minimal types to satisfy 'ChartContainer' references:
export type ChartConfig = Record<string, any>

export function ChartContainer(
  { config, className, children } : {
    config: ChartConfig
    className?: string
    children: React.ReactNode
  }
) {
  return (
    <div className={`relative overflow-hidden ${className || ""}`}>
      {children}
    </div>
  )
}

// Minimal tooltip wrappers:
export function ChartTooltip(props: any) {
  // This can pass its props directly to e.g. Recharts <Tooltip />
  return <>{props.children}</>
}

export function ChartTooltipContent(props: any) {
  // Just a stub for your custom content
  return <div className={props.className || ""}>{props.labelFormatter?.(props.label)}</div>
}
