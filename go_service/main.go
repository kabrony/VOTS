package main

import (
    "fmt"
    "log"
    "net/http"
    "os"
    "os/signal"
    "syscall"
)

func main() {
    http.HandleFunc("/go_task", func(w http.ResponseWriter, r *http.Request) {
        fmt.Fprintln(w, "Hello from Go Service! (Networking tasks)")
    })

    http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
        fmt.Fprintln(w, "OK")
    })

    srv := &http.Server{Addr: ":4000"}
    go func() {
        log.Println("Go Service => :4000 (Use /health)")
        if err := srv.ListenAndServe(); err != http.ErrServerClosed {
            log.Fatalf("ListenAndServe(): %v", err)
        }
    }()

    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    <-quit
    log.Println("Shutting down Go Service gracefully...")
    srv.Shutdown(nil)
}
