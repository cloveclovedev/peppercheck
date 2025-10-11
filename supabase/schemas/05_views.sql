-- Views
CREATE OR REPLACE VIEW "public"."judgements_ext" AS
 SELECT "j"."id",
    "j"."task_id",
    "j"."referee_id",
    "j"."comment",
    "j"."status",
    "j"."created_at",
    "j"."updated_at",
    "j"."is_confirmed",
    "j"."reopen_count",
    "j"."is_evidence_timeout_confirmed",
    (("j"."status" = 'rejected'::"text") AND ("j"."reopen_count" < 1) AND ("t"."due_date" > "now"()) AND (EXISTS ( SELECT 1
           FROM "public"."task_evidences" "te"
          WHERE (("te"."task_id" = "j"."task_id") AND ("te"."updated_at" > "j"."updated_at"))))) AS "can_reopen"
   FROM ("public"."judgements" "j"
     JOIN "public"."tasks" "t" ON (("j"."task_id" = "t"."id")));

COMMENT ON VIEW "public"."judgements_ext" IS 'Extended judgements view with can_reopen calculation for rejection reopening functionality. Automatically includes all judgements table columns. RLS inherited from judgements table.';

