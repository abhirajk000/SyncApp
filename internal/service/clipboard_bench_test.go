package service

import (
	"context"
	"fmt"
	"strings"
	"testing"

	"github.com/google/uuid"
)

func newBenchService(b *testing.B) *ClipboardService {
	b.Helper()
	return NewClipboardService(
		&stubClipboardStore{},
		&stubSettingsStore{},
		nil,
		nil,
		nil,
		10,
		120,
		1<<30,
	)
}

func BenchmarkSync_Short(b *testing.B) {
	svc := newBenchService(b)
	ctx := context.Background()
	userID := uuid.New()
	deviceID := uuid.New()
	content := "Hello, SyncBridge!"

	b.ResetTimer()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		c := fmt.Sprintf("%s-%d", content, i)
		if _, _, err := svc.Sync(ctx, userID, deviceID, "text/plain", c); err != nil {
			b.Fatalf("Sync: %v", err)
		}
	}
}

func BenchmarkSync_1KB(b *testing.B) {
	svc := newBenchService(b)
	ctx := context.Background()
	userID := uuid.New()
	deviceID := uuid.New()
	base := strings.Repeat("A", 1024)

	b.ResetTimer()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		c := fmt.Sprintf("%s%d", base, i)
		if _, _, err := svc.Sync(ctx, userID, deviceID, "text/plain", c); err != nil {
			b.Fatalf("Sync: %v", err)
		}
	}
}

func BenchmarkSync_10KB(b *testing.B) {
	svc := newBenchService(b)
	ctx := context.Background()
	userID := uuid.New()
	deviceID := uuid.New()
	base := strings.Repeat("A", 10*1024)

	b.ResetTimer()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		c := fmt.Sprintf("%s%d", base, i)
		if _, _, err := svc.Sync(ctx, userID, deviceID, "text/html", c); err != nil {
			b.Fatalf("Sync: %v", err)
		}
	}
}

func BenchmarkSync_Dedup(b *testing.B) {
	svc := newBenchService(b)
	ctx := context.Background()
	userID := uuid.New()
	deviceID := uuid.New()
	content := "same content repeated"

	if _, _, err := svc.Sync(ctx, userID, deviceID, "text/plain", content); err != nil {
		b.Fatalf("prime Sync: %v", err)
	}

	b.ResetTimer()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		if _, _, err := svc.Sync(ctx, userID, deviceID, "text/plain", content); err != nil {
			b.Fatalf("Sync: %v", err)
		}
	}
}

func BenchmarkGetHistory_50(b *testing.B) {
	svc := newBenchService(b)
	ctx := context.Background()
	userID := uuid.New()
	deviceID := uuid.New()

	for i := 0; i < 50; i++ {
		if _, _, err := svc.Sync(ctx, userID, deviceID, "text/plain",
			fmt.Sprintf("item %d %s", i, strings.Repeat("x", 100))); err != nil {
			b.Fatalf("seed: %v", err)
		}
	}

	b.ResetTimer()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		if _, err := svc.GetHistory(ctx, userID, 50, 0); err != nil {
			b.Fatalf("GetHistory: %v", err)
		}
	}
}
