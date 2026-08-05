package fcm

import "testing"

func TestBuildMulticastUsesLocKeys(t *testing.T) {
	msg := Message{
		TitleLocKey: "notification_task_assigned_referee_title",
		BodyLocKey:  "notification_task_assigned_referee_body",
		LocArgs:     []string{"Wash the car"},
		Data:        map[string]string{"route": "/tasks/1"},
	}
	mm := buildMulticast([]string{"tok1", "tok2"}, msg)

	if len(mm.Tokens) != 2 {
		t.Fatalf("want 2 tokens, got %d", len(mm.Tokens))
	}
	if mm.Data["route"] != "/tasks/1" {
		t.Fatalf("data not carried through: %v", mm.Data)
	}
	if mm.Android == nil || mm.Android.Notification == nil {
		t.Fatal("android notification missing")
	}
	if mm.Android.Priority != "high" {
		t.Fatalf("android priority = %q, want high (Doze delivery)", mm.Android.Priority)
	}
	if mm.APNS.Payload.Aps.Sound != "default" {
		t.Fatalf("apns sound = %q, want default", mm.APNS.Payload.Aps.Sound)
	}
	if mm.Android.Notification.TitleLocKey != msg.TitleLocKey {
		t.Fatalf("android title loc key = %q, want %q", mm.Android.Notification.TitleLocKey, msg.TitleLocKey)
	}
	if mm.Android.Notification.BodyLocKey != msg.BodyLocKey {
		t.Fatalf("android body loc key = %q, want %q", mm.Android.Notification.BodyLocKey, msg.BodyLocKey)
	}
	if mm.APNS == nil || mm.APNS.Payload == nil || mm.APNS.Payload.Aps == nil || mm.APNS.Payload.Aps.Alert == nil {
		t.Fatal("APNS alert payload missing")
	}
	alert := mm.APNS.Payload.Aps.Alert
	if alert.TitleLocKey != msg.TitleLocKey || alert.LocKey != msg.BodyLocKey {
		t.Fatalf("apns loc keys = (%q,%q), want (%q,%q)", alert.TitleLocKey, alert.LocKey, msg.TitleLocKey, msg.BodyLocKey)
	}
	if len(alert.LocArgs) != 1 || alert.LocArgs[0] != "Wash the car" {
		t.Fatalf("apns loc args = %v", alert.LocArgs)
	}
}

func TestChunkTokensRespectsMulticastLimit(t *testing.T) {
	mk := func(n int) []string {
		s := make([]string, n)
		for i := range s {
			s[i] = "t"
		}
		return s
	}
	cases := []struct {
		n          int
		wantChunks int
		wantLast   int
	}{
		{0, 0, 0},
		{1, 1, 1},
		{maxMulticastTokens, 1, maxMulticastTokens},
		{maxMulticastTokens + 1, 2, 1},
		{2*maxMulticastTokens + 3, 3, 3},
	}
	for _, c := range cases {
		got := chunkTokens(mk(c.n), maxMulticastTokens)
		if len(got) != c.wantChunks {
			t.Fatalf("n=%d: chunks=%d, want %d", c.n, len(got), c.wantChunks)
		}
		total := 0
		for _, b := range got {
			if len(b) > maxMulticastTokens {
				t.Fatalf("n=%d: a batch has %d > %d tokens", c.n, len(b), maxMulticastTokens)
			}
			total += len(b)
		}
		if total != c.n {
			t.Fatalf("n=%d: batched %d tokens total", c.n, total)
		}
		if c.wantChunks > 0 && len(got[len(got)-1]) != c.wantLast {
			t.Fatalf("n=%d: last batch=%d, want %d", c.n, len(got[len(got)-1]), c.wantLast)
		}
	}
}

func TestBuildMulticastCarriesArgsToBothPlatforms(t *testing.T) {
	msg := Message{TitleLocKey: "t", BodyLocKey: "b", LocArgs: []string{"x"}}
	mm := buildMulticast([]string{"tok"}, msg)
	if len(mm.Android.Notification.TitleLocArgs) != 1 || len(mm.Android.Notification.BodyLocArgs) != 1 {
		t.Fatalf("android loc args not set on both title and body")
	}
	if len(mm.APNS.Payload.Aps.Alert.TitleLocArgs) != 1 {
		t.Fatalf("apns title loc args not set")
	}
}
