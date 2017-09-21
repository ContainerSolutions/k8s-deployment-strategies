package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

func main() {
	// graceful shutdown
	quit := make(chan os.Signal)
	signal.Notify(quit, syscall.SIGTERM, syscall.SIGINT)

	srv := &http.Server{Addr: ":8080", Handler: http.DefaultServeMux}

	// http endpoints
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		datetime := time.Now()
		hostname, err := os.Hostname()

		if err != nil {
			fmt.Fprintf(w, "%v - Error getting hostname\n", datetime)
			return
		}

		fmt.Fprintf(w, "%v - Host: %s, Version: %s\n", datetime, hostname, os.Getenv("VERSION"))
	})

	http.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintln(w, "OK")
	})

	done := make(chan bool)

	go func() {
		<-quit

		d := time.Now().Add(5 * time.Second) // deadline 5s max
		ctx, cancel := context.WithDeadline(context.Background(), d)

		defer cancel()

		log.Println("Shutting down server...")
		if err := srv.Shutdown(ctx); err != nil {
			log.Fatalf("Could not shutdown: %v", err)
		}
		close(done)
	}()

	log.Println("Server started at localhost:8080")
	err := srv.ListenAndServe()

	if err != http.ErrServerClosed {
		log.Fatalf("Listen: %s\n", err)
	}

	log.Println("Server gracefully stopped")
	<-done
}
