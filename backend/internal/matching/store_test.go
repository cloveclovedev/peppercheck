package matching_test

import (
	"context"
	"database/sql"
	"errors"
	"os"
	"testing"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/database"
	"github.com/cloveclovedev/peppercheck/backend/internal/matching"
	"github.com/cloveclovedev/peppercheck/backend/internal/testsupport"
)

// The integration DB is shared across every test in the package and rows
// persist (no per-test cleanup). Candidate selection is global by design — any
// referee available at a task's due instant qualifies — so two tasks whose due
// instants share a weekday+minute would cross-contaminate each other's results.
// TestMain gives each seeded task a globally-unique due instant by advancing a
// persistent sequence (unique across runs of the shared iteration DB too), and
// the seed helpers cut each referee a one-minute slot around exactly that
// instant. Distinct tasks therefore never see each other's referees.
func TestMain(m *testing.M) {
	if dsn := os.Getenv("DATABASE_URL"); dsn != "" {
		db, err := database.Connect(context.Background(), dsn)
		if err == nil {
			_, _ = db.Exec(`CREATE SEQUENCE IF NOT EXISTS test_matching_bucket`)
			_ = db.Close()
		}
	}
	os.Exit(m.Run())
}

// --- seed helpers (shared by store/service/sweep tests) -------------------
//
// The integration DB is shared across tests and rows persist, so every helper
// mints fresh users (new uuids) and derives globally-unique usernames from the
// user id. Candidate selection is scoped by request id and workload by referee
// id, so freshly-minted rows never collide with another test's data.

// newUser inserts a bare identity anchor and returns its id.
func newUser(t *testing.T, db *sql.DB) string {
	t.Helper()
	var id string
	if err := db.QueryRow(`INSERT INTO public.users DEFAULT VALUES RETURNING id`).Scan(&id); err != nil {
		t.Fatalf("seed user: %v", err)
	}
	return id
}

// newReferee inserts a user + profile (timezone UTC), returning the user id. A
// profile is required because candidate selection joins profiles for timezone.
func newReferee(t *testing.T, db *sql.DB) string {
	t.Helper()
	id := newUser(t, db)
	if _, err := db.Exec(
		`INSERT INTO public.profiles (id, username, timezone)
		 VALUES ($1, left(replace($2, '-', ''), 16), 'UTC')`, id, id); err != nil {
		t.Fatalf("seed profile: %v", err)
	}
	return id
}

// newTask inserts an open task authored by taskerID whose due_date is a fixed
// far-future instant (well within the matching window) offset by a
// globally-unique number of minutes. Anchoring to a constant base — not now() —
// makes each task's UTC minute-of-day deterministic and unique, so its
// referees' one-minute slots never overlap another task's due instant.
func newTask(t *testing.T, db *sql.DB, taskerID string) string {
	t.Helper()
	var id string
	if err := db.QueryRow(
		`INSERT INTO public.tasks (tasker_id, title, status, due_date)
		 VALUES ($1, 'seed', 'open',
		         timestamptz '2027-06-01 00:00:00+00' + (nextval('test_matching_bucket') * interval '2 minutes'))
		 RETURNING id`, taskerID).Scan(&id); err != nil {
		t.Fatalf("seed task: %v", err)
	}
	return id
}

// newTaskDueIn inserts an open task whose due_date is `dueInterval` from now
// (e.g. '5 hours' to sit inside the rematch cutoff). Used by accept-window tests
// where candidate selection is not exercised, so no unique-minute slot is needed.
func newTaskDueIn(t *testing.T, db *sql.DB, taskerID, dueInterval string) string {
	t.Helper()
	var id string
	if err := db.QueryRow(
		`INSERT INTO public.tasks (tasker_id, title, status, due_date)
		 VALUES ($1, 'seed', 'open', now() + $2::interval) RETURNING id`, taskerID, dueInterval).Scan(&id); err != nil {
		t.Fatalf("seed task: %v", err)
	}
	return id
}

// addAllDaySlot gives a referee an active slot covering exactly the one-minute
// window around the task's due instant (in UTC). A narrow window keeps the seed
// isolated: only referees seeded for this task match its due minute.
func addAllDaySlot(t *testing.T, db *sql.DB, refereeID, taskID string) {
	t.Helper()
	if _, err := db.Exec(
		`INSERT INTO public.referee_available_time_slots (user_id, dow, start_min, end_min)
		 SELECT $1,
		        EXTRACT(DOW FROM (due_date AT TIME ZONE 'UTC'))::int,
		        (EXTRACT(HOUR FROM (due_date AT TIME ZONE 'UTC')) * 60
		           + EXTRACT(MINUTE FROM (due_date AT TIME ZONE 'UTC')))::int,
		        (EXTRACT(HOUR FROM (due_date AT TIME ZONE 'UTC')) * 60
		           + EXTRACT(MINUTE FROM (due_date AT TIME ZONE 'UTC')))::int + 1
		 FROM public.tasks WHERE id = $2`, refereeID, taskID); err != nil {
		t.Fatalf("seed time slot: %v", err)
	}
}

// blockOnDueDate marks the referee unavailable on the task's due date.
func blockOnDueDate(t *testing.T, db *sql.DB, refereeID, taskID string) {
	t.Helper()
	if _, err := db.Exec(
		`INSERT INTO public.referee_blocked_dates (user_id, start_date, end_date)
		 SELECT $1, (due_date AT TIME ZONE 'UTC')::date, (due_date AT TIME ZONE 'UTC')::date
		 FROM public.tasks WHERE id = $2`, refereeID, taskID); err != nil {
		t.Fatalf("seed blocked date: %v", err)
	}
}

// setAvailability upserts the referee's availability knobs. maxConcurrent < 0
// means "no cap" (stored as NULL).
func setAvailability(t *testing.T, db *sql.DB, refereeID string, accepting bool, maxConcurrent int) {
	t.Helper()
	var cap any
	if maxConcurrent >= 0 {
		cap = maxConcurrent
	}
	if _, err := db.Exec(
		`INSERT INTO public.referee_availability (user_id, is_accepting, max_concurrent_assignments)
		 VALUES ($1, $2, $3)
		 ON CONFLICT (user_id) DO UPDATE SET is_accepting = $2, max_concurrent_assignments = $3`,
		refereeID, accepting, cap); err != nil {
		t.Fatalf("seed availability: %v", err)
	}
}

// newPendingRequest inserts a pending referee_request for a task via the store's
// InsertRequestInTx (exercising it), returning its id.
func newPendingRequest(t *testing.T, db *sql.DB, taskID string) string {
	t.Helper()
	id, err := matching.NewStore(db).InsertRequestInTx(context.Background(), db, taskID)
	if err != nil {
		t.Fatalf("seed request: %v", err)
	}
	return id
}

// addActiveAssignment gives refereeID one unit of workload: a fresh task with an
// accepted request matched to them and an awaiting_evidence judgement.
func addActiveAssignment(t *testing.T, db *sql.DB, refereeID, taskerID string) {
	t.Helper()
	taskID := newTask(t, db, taskerID)
	var reqID string
	if err := db.QueryRow(
		`INSERT INTO public.referee_requests (task_id, status, matched_referee_id)
		 VALUES ($1, 'accepted', $2) RETURNING id`, taskID, refereeID).Scan(&reqID); err != nil {
		t.Fatalf("seed accepted request: %v", err)
	}
	if _, err := db.Exec(
		`INSERT INTO public.judgements (id, status) VALUES ($1, 'awaiting_evidence')`, reqID); err != nil {
		t.Fatalf("seed judgement: %v", err)
	}
}

// seedMatchingScenario builds the exclusion scenario: referee A fully available;
// B blocked on the due date; C not accepting. Returns the request id and A's id.
func seedMatchingScenario(t *testing.T, db *sql.DB) (requestID, refereeA string) {
	t.Helper()
	tasker := newUser(t, db)
	taskID := newTask(t, db, tasker)

	a := newReferee(t, db)
	addAllDaySlot(t, db, a, taskID)

	b := newReferee(t, db)
	addAllDaySlot(t, db, b, taskID)
	blockOnDueDate(t, db, b, taskID)

	c := newReferee(t, db)
	addAllDaySlot(t, db, c, taskID)
	setAvailability(t, db, c, false, -1)

	return newPendingRequest(t, db, taskID), a
}

// --- tests ----------------------------------------------------------------

func TestCandidateRefereesAppliesExclusions(t *testing.T) {
	db := testsupport.DB(t)
	s := matching.NewStore(db)
	reqID, wantA := seedMatchingScenario(t, db)

	got, err := s.CandidateReferees(context.Background(), db, reqID)
	if err != nil {
		t.Fatalf("candidates: %v", err)
	}
	if len(got) != 1 || got[0] != wantA {
		t.Fatalf("want [A=%s], got %v", wantA, got)
	}
}

func TestCandidateRefereesLeastWorkloadOnly(t *testing.T) {
	db := testsupport.DB(t)
	s := matching.NewStore(db)
	tasker := newUser(t, db)
	taskID := newTask(t, db, tasker)

	busy := newReferee(t, db)
	addAllDaySlot(t, db, busy, taskID)
	addActiveAssignment(t, db, busy, tasker) // workload 1

	idle := newReferee(t, db)
	addAllDaySlot(t, db, idle, taskID) // workload 0

	reqID := newPendingRequest(t, db, taskID)
	got, err := s.CandidateReferees(context.Background(), db, reqID)
	if err != nil {
		t.Fatalf("candidates: %v", err)
	}
	if len(got) != 1 || got[0] != idle {
		t.Fatalf("want only least-workload [idle=%s], got %v", idle, got)
	}
}

func TestMarkAcceptedInTx(t *testing.T) {
	db := testsupport.DB(t)
	s := matching.NewStore(db)
	ctx := context.Background()

	t.Run("accepts within the matching window", func(t *testing.T) {
		tasker := newUser(t, db)
		taskID := newTaskDueIn(t, db, tasker, "30 days")
		referee := newReferee(t, db)
		reqID := newPendingRequest(t, db, taskID)

		var won bool
		if err := database.WithTx(ctx, db, func(tx database.Querier) error {
			var e error
			won, e = s.MarkAcceptedInTx(ctx, tx, reqID, referee, false)
			return e
		}); err != nil {
			t.Fatalf("mark accepted: %v", err)
		}
		if !won {
			t.Fatal("want won=true within the window")
		}
		var status, matched string
		if err := db.QueryRow(`SELECT status, matched_referee_id FROM public.referee_requests WHERE id=$1`, reqID).Scan(&status, &matched); err != nil {
			t.Fatalf("scan: %v", err)
		}
		if status != "accepted" || matched != referee {
			t.Fatalf("want accepted->%s, got %s/%s", referee, status, matched)
		}
	})

	t.Run("same referee twice on one task returns ErrRefereeTaken", func(t *testing.T) {
		tasker := newUser(t, db)
		taskID := newTaskDueIn(t, db, tasker, "30 days")
		referee := newReferee(t, db)
		req1 := newPendingRequest(t, db, taskID)
		req2 := newPendingRequest(t, db, taskID)

		if err := database.WithTx(ctx, db, func(tx database.Querier) error {
			_, e := s.MarkAcceptedInTx(ctx, tx, req1, referee, false)
			return e
		}); err != nil {
			t.Fatalf("first accept: %v", err)
		}
		err := database.WithTx(ctx, db, func(tx database.Querier) error {
			_, e := s.MarkAcceptedInTx(ctx, tx, req2, referee, false)
			return e
		})
		if !errors.Is(err, matching.ErrRefereeTaken) {
			t.Fatalf("want ErrRefereeTaken, got %v", err)
		}
	})

	t.Run("past the rematch cutoff does not accept", func(t *testing.T) {
		tasker := newUser(t, db)
		taskID := newTaskDueIn(t, db, tasker, "5 hours") // inside the 14h rematch cutoff
		referee := newReferee(t, db)
		reqID := newPendingRequest(t, db, taskID)

		var won bool
		if err := database.WithTx(ctx, db, func(tx database.Querier) error {
			var e error
			won, e = s.MarkAcceptedInTx(ctx, tx, reqID, referee, false)
			return e
		}); err != nil {
			t.Fatalf("mark accepted: %v", err)
		}
		if won {
			t.Fatal("want won=false past the cutoff")
		}
		var status string
		_ = db.QueryRow(`SELECT status FROM public.referee_requests WHERE id=$1`, reqID).Scan(&status)
		if status != "pending" {
			t.Fatalf("want request left pending, got %s", status)
		}
	})
}

func TestCandidateRefereesRespectsMaxConcurrent(t *testing.T) {
	db := testsupport.DB(t)
	s := matching.NewStore(db)
	tasker := newUser(t, db)
	taskID := newTask(t, db, tasker)

	atCap := newReferee(t, db)
	addAllDaySlot(t, db, atCap, taskID)
	setAvailability(t, db, atCap, true, 1)
	addActiveAssignment(t, db, atCap, tasker) // workload 1 == cap -> excluded

	reqID := newPendingRequest(t, db, taskID)
	got, err := s.CandidateReferees(context.Background(), db, reqID)
	if err != nil {
		t.Fatalf("candidates: %v", err)
	}
	if len(got) != 0 {
		t.Fatalf("want no candidates (referee at cap), got %v", got)
	}
}
