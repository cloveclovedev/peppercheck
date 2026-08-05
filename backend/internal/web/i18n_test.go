package web

import "testing"

func TestCatalogT(t *testing.T) {
	if got := cat.T("en", "HomePage.titleLine1"); got != "Peer Referee Platform" {
		t.Fatalf("en HomePage.titleLine1 = %q", got)
	}
	if got := cat.T("ja", "HomePage.subtitle"); got != "あなたのタスクを第三者がチェック。習慣化を支え、質を高めるレフリーマッチングサービス。" {
		t.Fatalf("ja HomePage.subtitle = %q", got)
	}
	if got := cat.T("en", "Missing.key"); got != "Missing.key" {
		t.Fatalf("missing key should echo the key, got %q", got)
	}
}
