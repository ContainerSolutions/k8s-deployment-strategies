package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"
)

type status struct {
	sync.RWMutex
	ready bool
}

func main() {
	// graceful shutdown
	quit := make(chan os.Signal)
	signal.Notify(quit, syscall.SIGTERM, syscall.SIGINT)

	s := &status{
		ready: false,
	}

	go runProbes(s)

	mux := http.NewServeMux()

	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		datetime := time.Now()
		hostname, err := os.Hostname()

		if err != nil {
			fmt.Fprintf(w, "%v - Error getting hostname\n", datetime)
			return
		}

		fmt.Fprintf(w, "%v - Host: %s, Version: %s\n", datetime, hostname, os.Getenv("VERSION"))
	})

	srv := &http.Server{Addr: ":8080", Handler: mux}

	go func() {
		log.Println("Server started at localhost:8080")
		err := srv.ListenAndServe()

		if err != http.ErrServerClosed {
			log.Fatalf("Listen: %s\n", err)
		}
	}()

	s.Lock()
	s.ready = true
	s.Unlock()

	<-quit

	log.Println("Shutting down server...")

	s.Lock()
	s.ready = false
	s.Unlock()

	// Wait for load balancer to remove the application from the pool
	time.Sleep(5 * time.Second)

	// Gracefully shutdown connections
	ctx, _ := context.WithTimeout(context.Background(), 5*time.Second)

	srv.Shutdown(ctx)
}

// runProbes run liveness and readiness endpoints
func runProbes(s *status) {
	log.Println("Probe listening on port :8081")

	mux := http.NewServeMux()

	mux.HandleFunc("/-/liveness", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("ok"))
	})

	mux.HandleFunc("/-/readiness", func(w http.ResponseWriter, r *http.Request) {
		s.RLock()
		defer s.RUnlock()

		log.Printf("Readiness: %v", s.ready)

		if s.ready {
			w.WriteHeader(http.StatusOK)
		} else {
			w.WriteHeader(http.StatusInternalServerError)
		}
	})

	srv := &http.Server{Addr: ":8081", Handler: mux}

	if err := srv.ListenAndServe(); err != nil {
		log.Fatal("Probe listener failed")
	}
}
