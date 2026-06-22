package storage

import (
	"bytes"
	"context"
	"fmt"
	"io"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

// S3Config holds credentials and endpoint info for the S3 backend.
type S3Config struct {
	// Endpoint is the S3-compatible host (e.g. "s3.amazonaws.com" or "minio:9000").
	Endpoint string
	// Bucket is the target bucket name.  It must already exist.
	Bucket string
	// Region is the AWS region (e.g. "us-east-1").  Ignored by MinIO.
	Region string
	// AccessKey / SecretKey are the S3 credentials.
	AccessKey string
	SecretKey string
	// UseSSL enables HTTPS when true.
	UseSSL bool
}

// S3Backend stores objects in an AWS S3-compatible service.
// Tested with AWS S3 and MinIO.  Any S3-compatible service should work.
type S3Backend struct {
	client *minio.Client
	bucket string
}

// NewS3Backend creates an S3Backend using the minio-go client.
func NewS3Backend(cfg S3Config) (*S3Backend, error) {
	if cfg.Endpoint == "" {
		return nil, fmt.Errorf("storage s3: endpoint is required")
	}
	if cfg.Bucket == "" {
		return nil, fmt.Errorf("storage s3: bucket is required")
	}

	client, err := minio.New(cfg.Endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(cfg.AccessKey, cfg.SecretKey, ""),
		Secure: cfg.UseSSL,
		Region: cfg.Region,
	})
	if err != nil {
		return nil, fmt.Errorf("storage s3: init client: %w", err)
	}
	return &S3Backend{client: client, bucket: cfg.Bucket}, nil
}

// Type returns "s3".
func (b *S3Backend) Type() string { return "s3" }

// Put uploads r to the bucket under key.
// If size is -1 the upload uses a streaming path (slightly less efficient).
func (b *S3Backend) Put(ctx context.Context, key string, r io.Reader, size int64, contentType string) error {
	opts := minio.PutObjectOptions{ContentType: contentType}
	_, err := b.client.PutObject(ctx, b.bucket, key, r, size, opts)
	if err != nil {
		return fmt.Errorf("storage s3 put %q: %w", key, err)
	}
	return nil
}

// Get downloads the object at key.
// Returns ErrNotFound if the object does not exist.
func (b *S3Backend) Get(ctx context.Context, key string) (io.ReadCloser, int64, error) {
	obj, err := b.client.GetObject(ctx, b.bucket, key, minio.GetObjectOptions{})
	if err != nil {
		return nil, 0, b.wrapErr(err, key)
	}
	info, err := obj.Stat()
	if err != nil {
		obj.Close()
		return nil, 0, b.wrapErr(err, key)
	}
	return obj, info.Size, nil
}

// Delete removes the object at key.
func (b *S3Backend) Delete(ctx context.Context, key string) error {
	err := b.client.RemoveObject(ctx, b.bucket, key, minio.RemoveObjectOptions{})
	if err != nil {
		return b.wrapErr(err, key)
	}
	return nil
}

// Exists reports whether the object at key is present in the bucket.
func (b *S3Backend) Exists(ctx context.Context, key string) (bool, error) {
	_, err := b.client.StatObject(ctx, b.bucket, key, minio.StatObjectOptions{})
	if err != nil {
		er := minio.ToErrorResponse(err)
		if er.Code == "NoSuchKey" || er.StatusCode == 404 {
			return false, nil
		}
		return false, fmt.Errorf("storage s3 exists %q: %w", key, err)
	}
	return true, nil
}

// PutBytes is a convenience wrapper for small in-memory buffers (e.g. thumbnails).
func (b *S3Backend) PutBytes(ctx context.Context, key string, data []byte, contentType string) error {
	return b.Put(ctx, key, bytes.NewReader(data), int64(len(data)), contentType)
}

// wrapErr translates minio errors to ErrNotFound where appropriate.
func (b *S3Backend) wrapErr(err error, key string) error {
	if err == nil {
		return nil
	}
	er := minio.ToErrorResponse(err)
	if er.Code == "NoSuchKey" || er.StatusCode == 404 {
		return ErrNotFound
	}
	return fmt.Errorf("storage s3 %q: %w", key, err)
}
