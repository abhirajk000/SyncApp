package ws

// hub_bench_test.go — benchmarks for Hub broadcast throughput.
//
// Run with:
//   go test ./internal/ws/... -bench=. -benchtime=3s -benchmem

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
)

// BenchmarkBroadcast_1Device measures the cost of broadcasting to 1 device.
func BenchmarkBroadcast_1Device(b *testing.B) {
	benchmarkBroadcast(b, 1)
}

// BenchmarkBroadcast_5Devices measures broadcasting to 5 devices (typical user).
func BenchmarkBroadcast_5Devices(b *testing.B) {
	benchmarkBroadcast(b, 5)
}

// BenchmarkBroadcast_20Devices stress-tests large device counts.
func BenchmarkBroadcast_20Devices(b *testing.B) {
	benchmarkBroadcast(b, 20)
}

func benchmarkBroadcast(b *testing.B, deviceCount int) {
	b.Helper()
	h := NewHub()
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go h.Run(ctx)
	time.Sleep(5 * time.Millisecond) // let hub start

	userID := uuid.New()
	clients := make([]*Client, deviceCount)
	for i := range clients {
		conn := newMockConn()
		c := &Client{
			hub:      h,
			conn:     conn,
			userID:   userID,
			deviceID: uuid.New(),
			send:     make(chan []byte, 512),
		}
		h.register <- c
		clients[i] = c
	}
	time.Sleep(10 * time.Millisecond) // registrations processed

	msg := []byte(`{"type":"clipboard.new","payload":{"content_type":"text/plain","content":"hello"}}`)

	// Drain goroutines so send channels don't block during the benchmark.
	for _, c := range clients {
		go func(cl *Client) {
			for range cl.send {
			}
		}(c)
	}

	b.ResetTimer()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		h.Broadcast(userID, msg, nil)
	}
	b.StopTimer()
}

// BenchmarkEncode_ClipboardNew measures the JSON encoding cost alone.
func BenchmarkEncode_ClipboardNew(b *testing.B) {
	entryID := uuid.New().String()
	deviceID := uuid.New().String()
	now := time.Now()

	b.ResetTimer()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		if _, err := EncodeClipboardNew(
			entryID, "text/plain", "Hello world", deviceID, 11,
			map[string]int64{deviceID: now.UnixNano()},
			now,
		); err != nil {
			b.Fatalf("encode: %v", err)
		}
	}
}
