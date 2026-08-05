package web

import "testing"

func TestCatalogT(t *testing.T) {
	if got := cat.T("en", "HomePage.title"); got != "Peer Referee Platform for Tasks" {
		t.Fatalf("en HomePage.title = %q", got)
	}
	if got := cat.T("ja", "HomePage.subtitle"); got != "あなたのタスクを第三者がチェック。習慣化を支え、質を高めるレフリーマッチングサービス。" {
		t.Fatalf("ja HomePage.subtitle = %q", got)
	}
	if got := cat.T("en", "Missing.key"); got != "Missing.key" {
		t.Fatalf("missing key should echo the key, got %q", got)
	}
}
