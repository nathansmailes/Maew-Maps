// Emails maewmaps@gmail.com every time someone reports a cat, photo or comment.
// Called by a Database Webhook on new rows in public.reports.
// Needs one secret: GMAIL_APP_PASSWORD (a Google "app password" for maewmaps@gmail.com).
import nodemailer from "npm:nodemailer@6.9.16";
import { createClient } from "npm:@supabase/supabase-js@2.117.3";

const ME = "maewmaps@gmail.com";
const REASONS: Record<string, string> = {
  rude: "Rude or hurtful", spam: "Spam or advert", fake: "Not a real cat",
  duplicate: "Same cat is already on the map", private: "Shows someone's face or private details",
};

Deno.serve(async (req) => {
  const body = await req.json().catch(() => ({}));
  const r = body.record;
  if (!r || !r.target_type) return new Response("no report", { status: 400 });

  const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const table = r.target_type === "cat" ? "cats" : r.target_type === "comment" ? "comments" : "cat_photos";
  const { data: item } = await db.from(table).select("*").eq("id", r.target_id).maybeSingle();
  const { count } = await db.from("reports").select("id", { count: "exact", head: true })
    .eq("target_type", r.target_type).eq("target_id", r.target_id);

  const what = r.target_type === "cat" ? item?.description
    : r.target_type === "comment" ? item?.body : "(a photo, see the cat_photos table)";
  const catId = r.target_type === "cat" ? r.target_id : item?.cat_id;
  const text = [
    `Someone reported a ${r.target_type} on Maew Maps.`,
    ``,
    `Reason: ${REASONS[r.reason] || r.reason}`,
    `What it says: ${what ?? "(already deleted)"}`,
    `Posted by user: ${item?.user_id ?? item?.created_by ?? "unknown"}`,
    `Reports so far: ${count ?? 1}${(count ?? 1) >= 3 ? " (now hidden automatically)" : " (3 reports hide it automatically)"}`,
    ``,
    catId ? `Cat id: ${catId}` : ``,
    `Review it in Supabase: Table Editor, schema "admin", report_queue.`,
    `To remove it for everyone, open the ${table} table and tick "hidden" on row ${r.target_id}.`,
    `Please check within 24 hours (Apple requires this).`,
  ].join("\n");

  const mail = nodemailer.createTransport({
    host: "smtp.gmail.com", port: 465, secure: true,
    auth: { user: ME, pass: Deno.env.get("GMAIL_APP_PASSWORD") },
  });
  await mail.sendMail({ from: `Maew Maps <${ME}>`, to: ME, subject: `⚑ Maew Maps report: ${r.target_type} (${REASONS[r.reason] || r.reason})`, text });
  return new Response("sent");
});
