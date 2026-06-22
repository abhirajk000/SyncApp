// Package thumbnail generates small JPEG preview images for uploaded files.
//
// Supported source types:
//   JPEG, PNG, GIF (first frame), WebP, BMP, TIFF
//
// Unsupported types (video, PDF, ZIP) return ErrUnsupported so callers can
// skip thumbnail generation without treating it as an error.
package thumbnail

import (
	"bytes"
	"errors"
	"image"
	"image/jpeg"

	// Register decoders so image.Decode can handle each format.
	_ "image/gif" // GIF
	_ "image/png" // PNG

	"golang.org/x/image/draw"
	_ "golang.org/x/image/tiff" // TIFF
	_ "golang.org/x/image/webp" // WebP
)

const (
	// ThumbSize is the maximum width or height of the generated thumbnail.
	ThumbSize = 128
	// JPEGQuality is the JPEG encoding quality (0–100).
	JPEGQuality = 65
)

// ErrUnsupported is returned when the MIME type has no thumbnail implementation.
var ErrUnsupported = errors.New("thumbnail: unsupported content type")

// Generator creates JPEG thumbnails from image data.
type Generator struct{}

// New creates a Generator.
func New() *Generator { return &Generator{} }

// CanThumbnail returns true when Generate would produce a thumbnail for mimeType.
func CanThumbnail(mimeType string) bool {
	switch mimeType {
	case "image/jpeg", "image/png", "image/gif",
		"image/webp", "image/tiff", "image/bmp":
		return true
	}
	return false
}

// Generate decodes src using mimeType as a hint, produces a small JPEG,
// and returns the encoded bytes.
func (g *Generator) Generate(src []byte, mimeType string) ([]byte, error) {
	if !CanThumbnail(mimeType) {
		return nil, ErrUnsupported
	}

	img, _, err := image.Decode(bytes.NewReader(src))
	if err != nil {
		return nil, err
	}

	thumb := scaleTo(img, ThumbSize, ThumbSize)
	return encodeJPEG(thumb)
}

// scaleTo resizes img to fit within maxW × maxH while preserving aspect ratio.
// Large sources are halved with fast scaling before the final high-quality pass.
func scaleTo(src image.Image, maxW, maxH int) image.Image {
	current := src
	for {
		bounds := current.Bounds()
		srcW := bounds.Dx()
		srcH := bounds.Dy()
		if srcW <= maxW*2 && srcH <= maxH*2 {
			break
		}
		nw := srcW / 2
		nh := srcH / 2
		if nw < 1 {
			nw = 1
		}
		if nh < 1 {
			nh = 1
		}
		dst := image.NewRGBA(image.Rect(0, 0, nw, nh))
		draw.ApproxBiLinear.Scale(dst, dst.Bounds(), current, bounds, draw.Over, nil)
		current = dst
	}

	bounds := current.Bounds()
	srcW := bounds.Dx()
	srcH := bounds.Dy()
	if srcW == 0 || srcH == 0 {
		return current
	}

	scaleX := float64(maxW) / float64(srcW)
	scaleY := float64(maxH) / float64(srcH)
	scale := scaleX
	if scaleY < scale {
		scale = scaleY
	}
	if scale >= 1.0 {
		return current
	}

	dstW := int(float64(srcW) * scale)
	dstH := int(float64(srcH) * scale)
	if dstW < 1 {
		dstW = 1
	}
	if dstH < 1 {
		dstH = 1
	}

	dst := image.NewRGBA(image.Rect(0, 0, dstW, dstH))
	draw.CatmullRom.Scale(dst, dst.Bounds(), current, bounds, draw.Over, nil)
	return dst
}

func encodeJPEG(img image.Image) ([]byte, error) {
	var buf bytes.Buffer
	if err := jpeg.Encode(&buf, img, &jpeg.Options{Quality: JPEGQuality}); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}
