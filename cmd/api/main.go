package main

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
	"github.com/syncbridge/api/internal/config"
	"github.com/syncbridge/api/internal/database"
	"github.com/syncbridge/api/internal/handler"
	"github.com/syncbridge/api/internal/server"
)

// Build metadata — injected by Dockerfile / Makefile via -ldflags.
// Keep in sync with internal/handler/health.go's exported vars.
var (
	version   = "dev"
	commit    = "unknown"
	buildDate = "unknown"
)

func main() {
	// Forward build metadata to the health handler before any other init.
	handler.Version = version
	handler.Commit = commit
	handler.BuildDate = buildDate

	// Bootstrap a readable logger for the config-load phase.
	// It is replaced with the configured logger as soon as config is loaded.
	log.Logger = log.Output(zerolog.ConsoleWriter{Out: os.Stderr, TimeFormat: time.RFC3339})

	cfg, err := config.Load()
	if err != nil {
		log.Fatal().Err(err).Msg("invalid configuration")
	}

	configureLogger(cfg)

	// ── Subcommand dispatch ───────────────────────────────────────────────────
	// The binary doubles as a migration CLI:
	//   ./api                 → start the API server
	//   ./api migrate         → apply pending migrations, then exit
	//   ./api migrate down N  → roll back N migrations, then exit
	//   ./api migrate status  → print migration status, then exit
	if len(os.Args) > 1 && os.Args[1] == "migrate" {
		ctx := context.Background()
		db, err := database.Connect(ctx, cfg)
		if err != nil {
			log.Fatal().Err(err).Msg("cannot connect to database")
		}
		defer db.Close()

		if err := runMigrateCommand(ctx, db, cfg, os.Args[2:]); err != nil {
			log.Fatal().Err(err).Msg("migration failed")
		}
		return
	}

	// ── Server startup ────────────────────────────────────────────────────────
	log.Info().
		Str("version", version).
		Str("commit", commit).
		Str("environment", cfg.Environment).
		Msg("starting SyncBridge API")

	// Root context cancelled on SIGINT/SIGTERM — propagates to the WS Hub.
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	db, err := database.Connect(ctx, cfg)
	if err != nil {
		log.Fatal().Err(err).Msg("cannot connect to database")
	}
	defer db.Close()

	if cfg.RunMigrationsOnStartup {
		if err := database.RunMigrations(ctx, db, cfg.MigrationsPath); err != nil {
			log.Fatal().Err(err).Msg("migrations failed")
		}
	}

	srv := server.New(cfg, db)

	// Start the WebSocket Hub event loop.  It stops when ctx is cancelled.
	srv.StartHub(ctx)

	// Start mDNS announcement so local devices can discover the server.
	srv.StartMDNS(ctx)

	// Start the data-retention cleanup job (runs every 10 minutes).
	srv.StartCleanup(ctx)

	go func() {
		log.Info().Str("addr", cfg.Addr()).Msg("server listening")
		if err := srv.Listen(cfg.Addr()); err != nil {
			log.Debug().Err(err).Msg("server stopped")
		}
	}()

	<-ctx.Done()
	stop() // release signal resources
	log.Info().Msg("shutdown signal received")

	// Give in-flight requests 30 s to complete.
	done := make(chan struct{})
	go func() {
		if err := srv.Shutdown(); err != nil {
			log.Error().Err(err).Msg("shutdown error")
		}
		close(done)
	}()

	select {
	case <-done:
		log.Info().Msg("server shutdown complete")
	case <-time.After(30 * time.Second):
		log.Warn().Msg("shutdown timeout — forcing exit")
	}
}

// ── helpers ───────────────────────────────────────────────────────────────────

func runMigrateCommand(ctx context.Context, db *database.DB, cfg *config.Config, args []string) error {
	sub := "up"
	if len(args) > 0 {
		sub = args[0]
	}

	switch sub {
	case "up", "":
		return database.RunMigrations(ctx, db, cfg.MigrationsPath)
	case "down":
		steps := 1
		if len(args) > 1 {
			if _, err := fmt.Sscan(args[1], &steps); err != nil || steps < 1 {
				steps = 1
			}
		}
		return database.RollbackMigrations(ctx, db, cfg.MigrationsPath, steps)
	case "status":
		return database.MigrationStatus(ctx, db, cfg.MigrationsPath)
	default:
		return fmt.Errorf("unknown migrate subcommand %q; use: up | down [N] | status", sub)
	}
}

func configureLogger(cfg *config.Config) {
	level, err := zerolog.ParseLevel(cfg.LogLevel)
	if err != nil {
		level = zerolog.InfoLevel
	}
	zerolog.SetGlobalLevel(level)

	if cfg.IsDevelopment() || cfg.LogFormat == "pretty" {
		log.Logger = log.Output(zerolog.ConsoleWriter{
			Out:        os.Stderr,
			TimeFormat: time.RFC3339,
		})
	} else {
		log.Logger = zerolog.New(os.Stderr).
			With().
			Timestamp().
			Str("service", "syncbridge-api").
			Str("version", version).
			Logger()
	}
}
