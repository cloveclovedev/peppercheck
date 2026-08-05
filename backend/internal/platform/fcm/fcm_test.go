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
