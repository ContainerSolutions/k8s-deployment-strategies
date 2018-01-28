package main

import (
	"context"
	"flag"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gorilla/mux"
	"github.com/heptiolabs/healthcheck"
	"github.com/justinas/alice"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/rs/zerolog"
	"github.com/rs/zerolog/hlog"
	"github.com/rs/zerolog/log"
)

var (
	addr        = flag.String("listen-address", ":8080", "The address to listen on for HTTP requests.")
	probeAddr   = flag.String("probe-address", ":8086", "The address to listen on for probe requests.")
	metricsAddr = flag.String("metrics-address", ":9101", "The address to listen on for Prometheus metrics requests.")

	inFlightGauge = prometheus.NewGauge(
		prometheus.GaugeOpts{
			Name: "in_flight_requests",
			Help: "A gauge of requests currently being served by the wrapped handler.",
		},
	)

	counter = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "http_requests_total",
			Help: "A counter for requests to the wrapped handler.",
			ConstLabels: map[string]string{
				"version": version,
			},
		},
		[]string{"code", "method"},
	)

	duration = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "request_duration_seconds",
			Help:    "A histogram of latencies for requests.",
			Buckets: []float64{.25, .5, 1, 2.5, 5, 10},
			ConstLabels: map[string]string{
				"version": version,
			},
		},
		[]string{"code", "method"},
	)

	responseSize = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "response_size_bytes",
			Help:    "A histogram of response sizes for requests.",
			Buckets: []float64{200, 500, 900, 1500},
			ConstLabels: map[string]string{
				"version": version,
			},
		},
		[]string{"code", "method"},
	)

	version string
)

func init() {
	prometheus.MustRegister(inFlightGauge, counter, duration, responseSize)
	version = os.Getenv("VERSION")
}

func main() {
	flag.Parse()

	// logs
	log := zerolog.New(os.Stdout).With().
		Timestamp().
		Str("version", version).
		Logger()

	// graceful shutdown
	quit := make(chan os.Signal)
	signal.Notify(quit, syscall.SIGTERM, syscall.SIGINT)

	// probes
	health := healthcheck.NewHandler()

	// router
	r := mux.NewRouter()
	c := alice.New(hlog.NewHandler(log), hlog.AccessHandler(accessLogger))

	s := r.Methods("GET").Subrouter()
	s.HandleFunc("/", httpHandler)

	srv := &http.Server{Addr: *addr, Handler: c.Then(promRequestHandler(r))}

	go serveMetrics(*metricsAddr)
	go serveHTTP(srv)
	go serveProbe(*probeAddr, health)

	<-quit

	log.Info().Msg("Shutting down server...")

	// Gracefully shutdown connections
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	srv.Shutdown(ctx)
}

func promRequestHandler(handler http.Handler) http.Handler {
	return promhttp.InstrumentHandlerInFlight(inFlightGauge,
		promhttp.InstrumentHandlerDuration(duration,
			promhttp.InstrumentHandlerCounter(counter,
				promhttp.InstrumentHandlerResponseSize(responseSize, handler),
			),
		),
	)
}

func accessLogger(r *http.Request, status, size int, dur time.Duration) {
	hlog.FromRequest(r).Info().
		Str("host", r.Host).
		Int("status", status).
		Int("size", size).
		Dur("duration_ms", dur).
		Msg("request")
}

func serveHTTP(srv *http.Server) {
	log.Info().Msgf("Server started at %s", srv.Addr)
	err := srv.ListenAndServe()

	if err != http.ErrServerClosed {
		log.Fatal().Err(err).Msgf("Listen: %s\n", err)
	}
}

func serveProbe(addr string, health healthcheck.Handler) {
	log.Info().Msgf("Probe server running at %s", *probeAddr)
	http.ListenAndServe(addr, health)
}

func serveMetrics(addr string) {
	log.Info().Msgf("Serving Prometheus metrics on port %s", addr)

	http.Handle("/metrics", promhttp.Handler())

	if err := http.ListenAndServe(addr, nil); err != nil {
		log.Error().Err(err).Msg("Starting Prometheus listener failed")
	}
}

func httpHandler(w http.ResponseWriter, r *http.Request) {
	hostname, err := os.Hostname()

	if err != nil {
		fmt.Fprintf(w, "Error getting hostname\n")
		return
	}

	fmt.Fprintf(w, "Host: %s, Version: %s\n", hostname, version)
}
