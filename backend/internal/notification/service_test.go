package notification

import (
	"context"
	"errors"
	"testing"
)

type fakeStore struct {
	upserts  int
	deletes  int
	lastUser string
	lastTok  string
	lastDev  string
}

func (f *fakeStore) UpsertToken(_ context.Context, userID, token, deviceType string) error {
	f.upserts++
	f.lastUser, f.lastTok, f.lastDev = userID, token, deviceType
	return nil
}

func (f *fakeStore) DeleteToken(_ context.Context, userID, token string) error {
	f.deletes++
	f.lastUser, f.lastTok = userID, token
	return nil
}

func TestRegisterTokenDelegates(t *testing.T) {
	f := &fakeStore{}
	s := NewService(f)
	if err := s.RegisterToken(context.Background(), "u1", "tok", "android"); err != nil {
		t.Fatalf("register: %v", err)
	}
	if f.upserts != 1 || f.lastUser != "u1" || f.lastTok != "tok" || f.lastDev != "android" {
		t.Fatalf("store not called with the caller's id/token/device: %+v", f)
	}
}

func TestRegisterTokenRejectsEmpty(t *testing.T) {
	f := &fakeStore{}
	s := NewService(f)
	if err := s.RegisterToken(context.Background(), "u1", "", "android"); !errors.Is(err, ErrInvalidArgument) {
		t.Fatalf("err = %v, want ErrInvalidArgument", err)
	}
	if f.upserts != 0 {
		t.Fatal("empty token must not reach the store")
	}
}

func TestDeleteTokenRejectsEmpty(t *testing.T) {
	f := &fakeStore{}
	s := NewService(f)
	if err := s.DeleteToken(context.Background(), "u1", ""); !errors.Is(err, ErrInvalidArgument) {
		t.Fatalf("err = %v, want ErrInvalidArgument", err)
	}
	if f.deletes != 0 {
		t.Fatal("empty token must not reach the store")
	}
}
