// Package r2 is a thin S3-compatible adapter over Cloudflare R2. AWS S3 SDK
// types stop at this package (the platform rule); callers depend only on the
// Uploader interface. Phase 3a uses a public-avatar presigned PUT plus a
// finalize Head and an inline-delete-previous Delete.
package r2

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-sdk-go-v2/service/s3/types"
)

// Config holds the R2 connection settings. Credentials are operator-provisioned
// and injected as secrets (never committed).
type Config struct {
	AccountID       string
	AccessKeyID     string
	SecretAccessKey string
	Bucket          string
	PublicDomain    string // host that serves the objects, e.g. "cdn.peppercheck.dev"
}

// PresignPutInput describes a presigned upload. ContentLength is best-effort
// signed; R2 enforces the signed Content-Type but not Content-Length, so size is
// backstopped by the caller's finalize Head — not guaranteed here.
type PresignPutInput struct {
	Key           string
	ContentType   string
	ContentLength int64
	TTL           time.Duration
}

// ObjectMetadata is the subset of HeadObject the finalize backstop needs.
type ObjectMetadata struct {
	ContentLength int64
	ContentType   string
}

// Uploader is the object-storage surface the profile feature depends on.
type Uploader interface {
	PresignPut(ctx context.Context, in PresignPutInput) (url string, err error)
	Head(ctx context.Context, key string) (ObjectMetadata, error)
	Delete(ctx context.Context, key string) error
}

// ErrObjectNotFound means Head found no object at the key.
var ErrObjectNotFound = errors.New("object not found")

// Client is the concrete R2 Uploader.
type Client struct {
	s3        *s3.Client
	presign   *s3.PresignClient
	bucket    string
	pubDomain string
}

// New builds a Client from R2 config. Required fields must be non-empty.
func New(cfg Config) (*Client, error) {
	if cfg.AccountID == "" || cfg.AccessKeyID == "" || cfg.SecretAccessKey == "" ||
		cfg.Bucket == "" || cfg.PublicDomain == "" {
		return nil, errors.New("r2: incomplete config (account id, access key, secret, bucket, public domain all required)")
	}
	endpoint := fmt.Sprintf("https://%s.r2.cloudflarestorage.com", cfg.AccountID)
	s3c := s3.New(s3.Options{
		Region:       "auto",
		BaseEndpoint: aws.String(endpoint),
		Credentials:  credentials.NewStaticCredentialsProvider(cfg.AccessKeyID, cfg.SecretAccessKey, ""),
		// Path-style keeps the bucket in the URL path (host stays the account
		// endpoint), which R2 supports and keeps presigned URLs predictable.
		UsePathStyle: true,
	})
	return &Client{
		s3:        s3c,
		presign:   s3.NewPresignClient(s3c),
		bucket:    cfg.Bucket,
		pubDomain: cfg.PublicDomain,
	}, nil
}

// PublicURL composes the public https URL an object is served from.
func (c *Client) PublicURL(key string) string {
	return fmt.Sprintf("https://%s/%s", c.pubDomain, key)
}

// PresignPut returns a presigned PUT URL. The signed Content-Type is enforced by
// R2; Content-Length is signed best-effort when > 0.
func (c *Client) PresignPut(ctx context.Context, in PresignPutInput) (string, error) {
	put := &s3.PutObjectInput{
		Bucket:      aws.String(c.bucket),
		Key:         aws.String(in.Key),
		ContentType: aws.String(in.ContentType),
	}
	if in.ContentLength > 0 {
		put.ContentLength = aws.Int64(in.ContentLength)
	}
	req, err := c.presign.PresignPutObject(ctx, put, s3.WithPresignExpires(in.TTL))
	if err != nil {
		return "", fmt.Errorf("presign put: %w", err)
	}
	return req.URL, nil
}

// Head returns the object's size and content type, or ErrObjectNotFound.
func (c *Client) Head(ctx context.Context, key string) (ObjectMetadata, error) {
	out, err := c.s3.HeadObject(ctx, &s3.HeadObjectInput{
		Bucket: aws.String(c.bucket),
		Key:    aws.String(key),
	})
	if err != nil {
		var nf *types.NotFound
		var nsk *types.NoSuchKey
		if errors.As(err, &nf) || errors.As(err, &nsk) {
			return ObjectMetadata{}, ErrObjectNotFound
		}
		return ObjectMetadata{}, fmt.Errorf("head object: %w", err)
	}
	var size int64
	if out.ContentLength != nil {
		size = *out.ContentLength
	}
	var ct string
	if out.ContentType != nil {
		ct = *out.ContentType
	}
	return ObjectMetadata{ContentLength: size, ContentType: ct}, nil
}

// Delete removes an object. Deleting a missing key is a no-op success on S3/R2.
func (c *Client) Delete(ctx context.Context, key string) error {
	_, err := c.s3.DeleteObject(ctx, &s3.DeleteObjectInput{
		Bucket: aws.String(c.bucket),
		Key:    aws.String(key),
	})
	if err != nil {
		return fmt.Errorf("delete object: %w", err)
	}
	return nil
}
