package server

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/fiber/v2/middleware/recover"
	"github.com/gofiber/fiber/v2/middleware/requestid"
	fiberws "github.com/gofiber/websocket/v2"
	"github.com/rs/zerolog/log"

	"github.com/syncbridge/api/internal/auth"
	"github.com/syncbridge/api/internal/config"
	"github.com/syncbridge/api/internal/database"
	"github.com/syncbridge/api/internal/handler"
	"github.com/syncbridge/api/internal/mdns"
	"github.com/syncbridge/api/internal/middleware"
	"github.com/syncbridge/api/internal/repository"
	"github.com/syncbridge/api/internal/service"
	"github.com/syncbridge/api/internal/signaling"
	stg "github.com/syncbridge/api/internal/storage"
	"github.com/syncbridge/api/internal/thumbnail"
	"github.com/syncbridge/api/internal/ws"
)

// Server owns the Fiber application, the WebSocket Hub, and all wired services.
type Server struct {
	app           *fiber.App
	cfg           *config.Config
	db            *database.DB
	hub           *ws.Hub
	Querier       *ws.Querier // exposed for use by future phase handlers
	mdnsAnnouncer *mdns.Announcer
	cleanupSvc    *service.CleanupService
}

// New constructs and wires the full application.
// Call hub.Run(ctx) separately (done inside Start) and Listen to begin serving.
func New(cfg *config.Config, db *database.DB) *Server {
	// Chunk uploads can be up to DefaultChunkSizeMB + overhead; set Fiber body
	// limit to 2× max chunk size to give gzip and multipart a small buffer.
	bodyLimit := (cfg.DefaultChunkSizeMB + 1) * 1024 * 1024 * 2

	app := fiber.New(fiber.Config{
		AppName:               "SyncBridge API",
		ReadTimeout:           120 * time.Second, // large uploads need more time
		WriteTimeout:          120 * time.Second,
		IdleTimeout:           60 * time.Second,
		BodyLimit:             bodyLimit,
		DisableStartupMessage: true,
		ErrorHandler:          errorHandler,
	})

	hub := ws.NewHub()

	s := &Server{
		app:     app,
		cfg:     cfg,
		db:      db,
		hub:     hub,
		Querier: ws.NewQuerier(hub),
	}
	s.registerMiddleware()
	s.registerRoutes()
	return s
}

// Listen starts the HTTP server on the given address.
func (s *Server) Listen(addr string) error {
	return s.app.Listen(addr)
}

// Shutdown gracefully drains in-flight requests.
func (s *Server) Shutdown() error {
	return s.app.Shutdown()
}

// StartHub launches the Hub event loop; it must be called before Listen.
// Pass a context derived from the main context so the hub stops on shutdown.
func (s *Server) StartHub(ctx context.Context) {
	go s.hub.Run(ctx)
}

// StartCleanup launches the data-retention cleanup goroutine.
// It stops automatically when ctx is cancelled (e.g. on application shutdown).
// Must be called after registerRoutes (which creates cleanupSvc).
func (s *Server) StartCleanup(ctx context.Context) {
	if s.cleanupSvc != nil {
		s.cleanupSvc.Start(ctx)
	}
}

// StartMDNS begins the mDNS service announcement if enabled in config.
// It stops automatically when ctx is cancelled.
func (s *Server) StartMDNS(ctx context.Context) {
	if !s.cfg.MDNSEnabled || s.mdnsAnnouncer == nil {
		return
	}
	if err := s.mdnsAnnouncer.Start(); err != nil {
		log.Warn().Err(err).Msg("mdns start failed; continuing without local discovery")
		return
	}
	go func() {
		<-ctx.Done()
		s.mdnsAnnouncer.Shutdown()
	}()
}

// ── private ───────────────────────────────────────────────────────────────────

func (s *Server) registerMiddleware() {
	s.app.Use(recover.New(recover.Config{
		EnableStackTrace: s.cfg.IsDevelopment(),
	}))
	s.app.Use(requestid.New())
	s.app.Use(middleware.ZerologLogger())
	s.app.Use(cors.New(cors.Config{
		AllowOrigins: strings.Join(s.cfg.CORSOrigins, ","),
		AllowHeaders: "Origin, Content-Type, Accept, Authorization, X-Request-ID, X-Chunk-Hash",
		AllowMethods: "GET, POST, PUT, PATCH, DELETE, OPTIONS",
	}))
}

func (s *Server) registerRoutes() {
	pool := s.db.Pool

	// ── Object storage ──────────────────────────────────────────────────────
	storageBackend, err := stg.New(s.cfg)
	if err != nil {
		panic("object storage init failed: " + err.Error())
	}
	log.Info().Str("type", storageBackend.Type()).Msg("object storage backend initialised")

	// ── mDNS announcer (Phase 6) ──────────────────────────────────────────────
	instanceID := s.cfg.MDNSInstanceID
	if instanceID == "" {
		instanceID = fmt.Sprintf("%p", s) // stable within process lifetime
	}
	s.mdnsAnnouncer = mdns.NewAnnouncer(mdns.AnnouncerConfig{
		InstanceName: s.cfg.MDNSInstanceName,
		Port:         s.cfg.Port,
		TXTRecords:   mdns.TXTRecords("v1", instanceID),
	})

	// ── Repositories ──────────────────────────────────────────────────────────
	deviceRepo       := repository.NewDeviceRepository(pool)
	sessionRepo    := repository.NewSessionRepository(pool)
	pairingRepo    := repository.NewPairingRepository(pool)
	auditRepo      := repository.NewAuditRepository(pool)
	clipboardRepo    := repository.NewClipboardRepository(pool)
	deliveryRepo     := repository.NewFileDeliveryRepository(pool)
	localPeerRepo    := repository.NewLocalPeerRepository(pool)
	fileRepo         := repository.NewFileRepository(pool)
	chunkRepo        := repository.NewFileChunkRepository(pool)
	userSettingsRepo := repository.NewUserSettingsRepository(pool)
	globalSettingsRepo := repository.NewGlobalSettingsRepository(pool)

	// ── Token service (7-day device sessions) ───────────────────────────────────
	trustTTL := time.Duration(s.cfg.DeviceTrustDays) * 24 * time.Hour
	tokenSvc := auth.NewTokenService(
		s.cfg.JWTSecret,
		trustTTL,
		trustTTL,
	)

	// ── Application services ──────────────────────────────────────────────────
	authSvc := service.NewAuthService(
		globalSettingsRepo, sessionRepo, deviceRepo, auditRepo,
		tokenSvc, trustTTL,
	)
	deviceSvc := service.NewDeviceService(
		deviceRepo, sessionRepo, pairingRepo, auditRepo,
		tokenSvc, 5*time.Minute,
	)
	clipboardSvc := service.NewClipboardService(
		clipboardRepo, userSettingsRepo,
		s.hub,
		storageBackend,
		thumbnail.New(),
		s.cfg.MaxClipboardSizeMB,
		s.cfg.DefaultRetentionMinutes,
		s.cfg.MaxUnpinnedBytes(),
	)
	signalingStore := signaling.NewStore()
	signalingSvc := service.NewSignalingService(
		signalingStore,
		localPeerRepo,
		s.hub,
		service.TURNConfig{
			STUNURLs: splitCSV(s.cfg.STUNURLs),
			TURNURLs: splitCSV(s.cfg.TURNURLs),
			Secret:   s.cfg.TURNSecret,
		},
	)
	fileSvc := service.NewFileService(
		fileRepo,
		chunkRepo,
		deliveryRepo,
		deviceRepo,
		userSettingsRepo,
		storageBackend,
		thumbnail.New(),
		s.hub,
		s.cfg.MaxFileSizeMB,
		s.cfg.DefaultChunkSizeMB*1024*1024,
		s.cfg.DefaultRetentionMinutes,
		s.cfg.MaxUnpinnedBytes(),
		int64(s.cfg.RelayAutoMaxMB)*1024*1024,
		int64(s.cfg.AutoCloudMaxMB)*1024*1024,
	)

	// ── Retention cleanup job ────────────────────────────────────────────────
	s.cleanupSvc = service.NewCleanupService(pool, storageBackend, 10*time.Minute)

	// ── Auth middleware ───────────────────────────────────────────────────────
	requireAuth := middleware.RequireAuth(tokenSvc)

	// ── Infrastructure health (no auth) ──────────────────────────────────────
	healthH := handler.NewHealthHandler(s.db)
	s.app.Get("/health",  healthH.Liveness)
	s.app.Get("/ready",   healthH.Readiness)
	s.app.Get("/version", healthH.Version)

	// ── API v1 ────────────────────────────────────────────────────────────────
	v1 := s.app.Group("/api/v1")

	// Auth (PIN unlock)
	authH := handler.NewAuthHandler(authSvc)
	authGroup := v1.Group("/auth")
	authGroup.Use(middleware.AuthRateLimit(s.cfg))
	authGroup.Post("/unlock",  authH.Unlock)
	authGroup.Get("/status",   requireAuth, authH.Status)
	authGroup.Post("/logout",  requireAuth, authH.Logout)

	// Devices
	deviceH := handler.NewDeviceHandler(deviceSvc)
	devicesGroup := v1.Group("/devices", requireAuth)
	devicesGroup.Get("/",               deviceH.List)
	devicesGroup.Get("/:id",            deviceH.Get)
	devicesGroup.Delete("/:id",         deviceH.Revoke)
	devicesGroup.Post("/:id/trust",     deviceH.Trust)
	devicesGroup.Post("/pair/initiate", deviceH.InitiatePairing)
	v1.Post("/devices/pair/confirm", middleware.AuthRateLimit(s.cfg), deviceH.ConfirmPairing)

	// ── WebSocket ─────────────────────────────────────────────────────────────
	// Route:  GET /ws
	//
	// Middleware stack (applied in order):
	//   1. UpgradeGuard   — reject plain HTTP with 426
	//   2. WSAuth         — validate JWT (header or ?token=), write uid/did to locals
	//   3. fiberws.New()  — perform the WebSocket upgrade and hand off to ServeWS
	//
	// Reconnect: clients simply re-connect and re-authenticate.  The hub evicts
	// the stale connection automatically (see hub.handleRegister).
	wsH := ws.NewHandler(s.hub)
	s.app.Use("/ws", ws.UpgradeGuard())
	s.app.Use("/ws", ws.WSAuth(tokenSvc))
	s.app.Get("/ws", fiberws.New(wsH.ServeWS))

	// ── Clipboard (Phase 5) ──────────────────────────────────────────────────
	clipboardH := handler.NewClipboardHandler(clipboardSvc)
	clipGroup := v1.Group("/clipboard", requireAuth)
	clipGroup.Post("/",           clipboardH.Sync)
	clipGroup.Get("/current",     clipboardH.GetCurrent)
	clipGroup.Get("/",            clipboardH.GetHistory)
	clipGroup.Get("/:id/thumbnail", clipboardH.DownloadThumbnail)
	clipGroup.Get("/:id",         clipboardH.GetByID)
	clipGroup.Delete("/:id",      clipboardH.Delete)
	clipGroup.Post("/:id/pin",    clipboardH.Pin)

	// ── WebRTC signaling + local discovery (Phase 6) ─────────────────────────
	signalH := handler.NewSignalingHandler(signalingSvc)

	// RTC config (no auth needed — client needs credentials before WS is open)
	v1.Get("/rtc/config", requireAuth, signalH.GetRTCConfig)

	// Signaling (all require auth)
	signalGroup := v1.Group("/signal", requireAuth)
	signalGroup.Post("/",                  signalH.CreateOffer)
	signalGroup.Get("/:id",               signalH.GetSession)
	signalGroup.Post("/:id/answer",       signalH.SubmitAnswer)
	signalGroup.Post("/:id/ice",          signalH.AddICECandidate)
	signalGroup.Post("/:id/connected",    signalH.MarkConnected)

	// Local peer discovery (all require auth)
	localGroup := v1.Group("/local", requireAuth)
	localGroup.Post("/advertise",    signalH.AdvertiseLocalAddrs)
	localGroup.Get("/peers",         signalH.GetLocalPeers)
	localGroup.Delete("/advertise",  signalH.RemoveLocalAddr)

	// ── File synchronisation (Phase 7) ───────────────────────────────────────
	//
	// Routing summary:
	//   POST   /api/v1/files/init           — allocate upload session
	//   GET    /api/v1/files                 — list user's files
	//   GET    /api/v1/files/:id             — file metadata
	//   GET    /api/v1/files/:id/status      — resume: which chunks are missing?
	//   PUT    /api/v1/files/:id/chunks/:n   — upload raw chunk (octet-stream)
	//   POST   /api/v1/files/:id/complete    — assemble, validate, compress, thumb
	//   GET    /api/v1/files/:id/download    — stream assembled file
	//   GET    /api/v1/files/:id/thumbnail   — stream 256×256 JPEG thumbnail
	//   DELETE /api/v1/files/:id             — soft-delete
	//
	// Transfer-mode:
	//   relay  — chunks travel through the server (default; any network).
	//   webrtc — P2P DataChannel transfer; server still stores a backup copy for
	//            offline devices (signaled via Phase 6 WebRTC signaling).
	fileH := handler.NewFileHandler(fileSvc)
	filesGroup := v1.Group("/files", requireAuth)
	filesGroup.Post("/init",               fileH.InitUpload)
	filesGroup.Get("/",                    fileH.ListFiles)
	filesGroup.Get("/:id",                 fileH.GetFile)
	filesGroup.Get("/:id/status",          fileH.GetUploadStatus)
	filesGroup.Put("/:id/chunks/:n",       fileH.UploadChunk)
	filesGroup.Post("/:id/complete",       fileH.CompleteUpload)
	filesGroup.Get("/:id/download",        fileH.Download)
	filesGroup.Get("/:id/thumbnail",       fileH.DownloadThumbnail)
	filesGroup.Post("/:id/delivered",       fileH.MarkDelivered)
	filesGroup.Post("/:id/pin",            fileH.SetPinned)
	filesGroup.Delete("/:id",              fileH.DeleteFile)

	// ── Settings (Phase 8) ───────────────────────────────────────────────────
	settingsH := handler.NewSettingsHandler(userSettingsRepo)
	settingsH.RegisterRoutes(v1.Group("", requireAuth))

	// ── Diagnostics (Phase 9) ────────────────────────────────────────────────
	diagH := handler.NewDiagnosticsHandler(
		localPeerRepo,
		userSettingsRepo,
		handler.DiagnosticsConfig{
			ServerVersion:           handler.Version,
			MDNSEnabled:             s.cfg.MDNSEnabled,
			STUNURLs:                s.cfg.STUNURLs,
			TURNEnabled:             s.cfg.TURNSecret != "",
			StorageBackend:          s.cfg.ObjectStorageType,
			DefaultRetentionMinutes: s.cfg.DefaultRetentionMinutes,
		},
	)
	v1.Get("/diagnostics", requireAuth, diagH.Get)
}

// splitCSV splits a comma-separated string into a trimmed slice.
// Empty string returns nil (not an empty slice) to simplify TURNConfig checks.
func splitCSV(s string) []string {
	if s == "" {
		return nil
	}
	parts := strings.Split(s, ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		if t := strings.TrimSpace(p); t != "" {
			out = append(out, t)
		}
	}
	return out
}

// errorHandler renders a consistent JSON error envelope.
func errorHandler(c *fiber.Ctx, err error) error {
	code := fiber.StatusInternalServerError
	msg := "internal server error"

	var fiberErr *fiber.Error
	if errors.As(err, &fiberErr) {
		code = fiberErr.Code
		msg = fiberErr.Message
	}

	reqID, _ := c.Locals("requestid").(string)
	return c.Status(code).JSON(fiber.Map{
		"error":      msg,
		"request_id": reqID,
	})
}
