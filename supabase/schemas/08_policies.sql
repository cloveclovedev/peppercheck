-- Row level security and policies
ALTER TABLE "public"."judgement_thread_assets" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."judgement_threads" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."judgements" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."rating_histories" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."referee_available_time_slots" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."task_evidence_assets" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."task_evidences" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."task_referee_requests" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."tasks" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."user_ratings" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "Judgements: insert if referee" ON "public"."judgements" FOR INSERT WITH CHECK (("referee_id" = ( SELECT "auth"."uid"() AS "uid")));

CREATE POLICY "Judgements: select if tasker or referee" ON "public"."judgements" FOR SELECT USING ((("referee_id" = ( SELECT "auth"."uid"() AS "uid")) OR "public"."is_task_tasker"("task_id", ( SELECT "auth"."uid"() AS "uid"))));

CREATE POLICY "Judgements: update if referee or tasker" ON "public"."judgements" FOR UPDATE USING ((("referee_id" = ( SELECT "auth"."uid"() AS "uid")) OR "public"."is_task_tasker"("task_id", ( SELECT "auth"."uid"() AS "uid"))));

CREATE POLICY "Profiles: public read" ON "public"."profiles" FOR SELECT USING (true);

CREATE POLICY "Profiles: update if self" ON "public"."profiles" FOR UPDATE USING (("id" = ( SELECT "auth"."uid"() AS "uid")));

CREATE POLICY "Rating Histories: insert if authenticated" ON "public"."rating_histories" FOR INSERT TO "authenticated" WITH CHECK (true);

CREATE POLICY "Rating Histories: select if task participant" ON "public"."rating_histories" FOR SELECT TO "authenticated" USING (((EXISTS ( SELECT 1
   FROM "public"."tasks" "t"
  WHERE (("t"."id" = "rating_histories"."task_id") AND ("t"."tasker_id" = ( SELECT "auth"."uid"() AS "uid"))))) OR (EXISTS ( SELECT 1
   FROM "public"."judgements" "j"
  WHERE (("j"."task_id" = "rating_histories"."task_id") AND ("j"."referee_id" = ( SELECT "auth"."uid"() AS "uid")))))));

CREATE POLICY "Task Evidence Assets: delete if tasker" ON "public"."task_evidence_assets" FOR DELETE USING ((EXISTS ( SELECT 1
   FROM ("public"."task_evidences" "te"
     JOIN "public"."tasks" "t" ON (("te"."task_id" = "t"."id")))
  WHERE (("te"."id" = "task_evidence_assets"."evidence_id") AND ("t"."tasker_id" = ( SELECT "auth"."uid"() AS "uid"))))));

CREATE POLICY "Task Evidence Assets: insert if tasker" ON "public"."task_evidence_assets" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM ("public"."task_evidences" "te"
     JOIN "public"."tasks" "t" ON (("te"."task_id" = "t"."id")))
  WHERE (("te"."id" = "task_evidence_assets"."evidence_id") AND ("t"."tasker_id" = ( SELECT "auth"."uid"() AS "uid"))))));

CREATE POLICY "Task Evidence Assets: select if tasker or referee" ON "public"."task_evidence_assets" FOR SELECT USING (((EXISTS ( SELECT 1
   FROM ("public"."task_evidences" "te"
     JOIN "public"."tasks" "t" ON (("te"."task_id" = "t"."id")))
  WHERE (("te"."id" = "task_evidence_assets"."evidence_id") AND ("t"."tasker_id" = ( SELECT "auth"."uid"() AS "uid"))))) OR (EXISTS ( SELECT 1
   FROM ("public"."task_evidences" "te"
     JOIN "public"."judgements" "j" ON (("te"."task_id" = "j"."task_id")))
  WHERE (("te"."id" = "task_evidence_assets"."evidence_id") AND ("j"."referee_id" = ( SELECT "auth"."uid"() AS "uid")))))));

CREATE POLICY "Task Evidence Assets: update if tasker" ON "public"."task_evidence_assets" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM ("public"."task_evidences" "te"
     JOIN "public"."tasks" "t" ON (("te"."task_id" = "t"."id")))
  WHERE (("te"."id" = "task_evidence_assets"."evidence_id") AND ("t"."tasker_id" = ( SELECT "auth"."uid"() AS "uid"))))));

CREATE POLICY "Task Evidences: delete if tasker" ON "public"."task_evidences" FOR DELETE USING ((EXISTS ( SELECT 1
   FROM "public"."tasks" "t"
  WHERE (("t"."id" = "task_evidences"."task_id") AND ("t"."tasker_id" = ( SELECT "auth"."uid"() AS "uid"))))));

CREATE POLICY "Task Evidences: insert if tasker" ON "public"."task_evidences" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."tasks" "t"
  WHERE (("t"."id" = "task_evidences"."task_id") AND ("t"."tasker_id" = ( SELECT "auth"."uid"() AS "uid"))))));

CREATE POLICY "Task Evidences: select if tasker or referee" ON "public"."task_evidences" FOR SELECT USING (((EXISTS ( SELECT 1
   FROM "public"."tasks" "t"
  WHERE (("t"."id" = "task_evidences"."task_id") AND ("t"."tasker_id" = ( SELECT "auth"."uid"() AS "uid"))))) OR (EXISTS ( SELECT 1
   FROM "public"."judgements" "j"
  WHERE (("j"."task_id" = "task_evidences"."task_id") AND ("j"."referee_id" = ( SELECT "auth"."uid"() AS "uid")))))));

CREATE POLICY "Task Evidences: update if tasker" ON "public"."task_evidences" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."tasks" "t"
  WHERE (("t"."id" = "task_evidences"."task_id") AND ("t"."tasker_id" = ( SELECT "auth"."uid"() AS "uid"))))));

CREATE POLICY "Tasks: delete if tasker" ON "public"."tasks" FOR DELETE USING (("tasker_id" = ( SELECT "auth"."uid"() AS "uid")));

CREATE POLICY "Tasks: insert if authenticated" ON "public"."tasks" FOR INSERT WITH CHECK (("tasker_id" = ( SELECT "auth"."uid"() AS "uid")));

CREATE POLICY "Tasks: select if tasker, referee, or referee candidate" ON "public"."tasks" FOR SELECT USING ((("tasker_id" = ( SELECT "auth"."uid"() AS "uid")) OR "public"."is_task_referee"("id", ( SELECT "auth"."uid"() AS "uid")) OR "public"."is_task_referee_candidate"("id", ( SELECT "auth"."uid"() AS "uid"))));

CREATE POLICY "Tasks: update if tasker" ON "public"."tasks" FOR UPDATE USING (("tasker_id" = ( SELECT "auth"."uid"() AS "uid")));

CREATE POLICY "Thread Assets: delete if sender" ON "public"."judgement_thread_assets" FOR DELETE USING ((EXISTS ( SELECT 1
   FROM "public"."judgement_threads" "jt"
  WHERE (("jt"."id" = "judgement_thread_assets"."thread_id") AND ("jt"."sender_id" = ( SELECT "auth"."uid"() AS "uid"))))));

CREATE POLICY "Thread Assets: insert if participant" ON "public"."judgement_thread_assets" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM (("public"."judgement_threads" "jt"
     JOIN "public"."judgements" "j" ON (("jt"."judgement_id" = "j"."id")))
     JOIN "public"."tasks" "t" ON (("j"."task_id" = "t"."id")))
  WHERE (("jt"."id" = "judgement_thread_assets"."thread_id") AND (("t"."tasker_id" = ( SELECT "auth"."uid"() AS "uid")) OR ("j"."referee_id" = ( SELECT "auth"."uid"() AS "uid")))))));

CREATE POLICY "Thread Assets: select if participant" ON "public"."judgement_thread_assets" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM (("public"."judgement_threads" "jt"
     JOIN "public"."judgements" "j" ON (("jt"."judgement_id" = "j"."id")))
     JOIN "public"."tasks" "t" ON (("j"."task_id" = "t"."id")))
  WHERE (("jt"."id" = "judgement_thread_assets"."thread_id") AND (("t"."tasker_id" = ( SELECT "auth"."uid"() AS "uid")) OR ("j"."referee_id" = ( SELECT "auth"."uid"() AS "uid")))))));

CREATE POLICY "Thread Assets: update if sender" ON "public"."judgement_thread_assets" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."judgement_threads" "jt"
  WHERE (("jt"."id" = "judgement_thread_assets"."thread_id") AND ("jt"."sender_id" = ( SELECT "auth"."uid"() AS "uid"))))));

CREATE POLICY "Threads: delete if sender" ON "public"."judgement_threads" FOR DELETE USING (("sender_id" = ( SELECT "auth"."uid"() AS "uid")));

CREATE POLICY "Threads: insert if participant" ON "public"."judgement_threads" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM ("public"."judgements" "j"
     JOIN "public"."tasks" "t" ON (("j"."task_id" = "t"."id")))
  WHERE (("j"."id" = "judgement_threads"."judgement_id") AND (("t"."tasker_id" = ( SELECT "auth"."uid"() AS "uid")) OR ("j"."referee_id" = ( SELECT "auth"."uid"() AS "uid")))))));

CREATE POLICY "Threads: select if participant" ON "public"."judgement_threads" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM ("public"."judgements" "j"
     JOIN "public"."tasks" "t" ON (("j"."task_id" = "t"."id")))
  WHERE (("j"."id" = "judgement_threads"."judgement_id") AND (("t"."tasker_id" = ( SELECT "auth"."uid"() AS "uid")) OR ("j"."referee_id" = ( SELECT "auth"."uid"() AS "uid")))))));

CREATE POLICY "Threads: update if sender" ON "public"."judgement_threads" FOR UPDATE USING (("sender_id" = ( SELECT "auth"."uid"() AS "uid")));

CREATE POLICY "referee_available_time_slots: delete for own records" ON "public"."referee_available_time_slots" FOR DELETE USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));

CREATE POLICY "referee_available_time_slots: insert for own records" ON "public"."referee_available_time_slots" FOR INSERT WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));

CREATE POLICY "referee_available_time_slots: select for all" ON "public"."referee_available_time_slots" FOR SELECT USING (true);

CREATE POLICY "referee_available_time_slots: update for own records" ON "public"."referee_available_time_slots" FOR UPDATE USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));

CREATE POLICY "task_referee_requests: insert if tasker" ON "public"."task_referee_requests" FOR INSERT WITH CHECK (("task_id" IN ( SELECT "tasks"."id"
   FROM "public"."tasks"
  WHERE ("tasks"."tasker_id" = ( SELECT "auth"."uid"() AS "uid")))));

CREATE POLICY "task_referee_requests: select for owners and assigned referees" ON "public"."task_referee_requests" FOR SELECT USING ((("task_id" IN ( SELECT "tasks"."id"
   FROM "public"."tasks"
  WHERE ("tasks"."tasker_id" = ( SELECT "auth"."uid"() AS "uid")))) OR ("matched_referee_id" = ( SELECT "auth"."uid"() AS "uid"))));

CREATE POLICY "task_referee_requests: update for assigned referees" ON "public"."task_referee_requests" FOR UPDATE USING (("matched_referee_id" = ( SELECT "auth"."uid"() AS "uid"))) WITH CHECK (("matched_referee_id" = ( SELECT "auth"."uid"() AS "uid")));

CREATE POLICY "user_ratings: select for all" ON "public"."user_ratings" FOR SELECT USING (true);

COMMENT ON POLICY "Tasks: select if tasker, referee, or referee candidate" ON "public"."tasks" IS 'Allow access to task details for taskers, assigned referees, and referee candidates. Referee candidates can only see task information, not judgements or evidences.';
