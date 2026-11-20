# Get an email for every report

Each time someone reports a cat, photo or comment, Supabase emails maewmaps@gmail.com.
It takes three steps in the Supabase dashboard (supabase.com/dashboard, project Maew Maps), about 10 minutes.

## 1. Make a Gmail app password
1. Sign in to Google as **maewmaps@gmail.com** and open https://myaccount.google.com/apppasswords
2. Name it `Maew Maps reports` and press **Create**.
3. Google shows a 16-letter password. Keep that page open for step 2. Don't paste it in chat.

## 2. Add the email function
1. In Supabase, open **Edge Functions** (left menu), then **Deploy a new function → Via Editor**.
2. Name it exactly `report-email`.
3. Delete the sample code, paste everything from `supabase/functions/report-email/index.ts`, and press **Deploy function**.
4. Open **Edge Functions → Secrets** and add a secret:
   name `GMAIL_APP_PASSWORD`, value = the 16-letter password (no spaces). Save.

## 3. Run it on each new report
1. Open **Database → Webhooks** (enable webhooks if asked) and press **Create a new hook**.
2. Name: `report-email`. Table: `reports`. Events: tick **Insert** only.
3. Type: **Supabase Edge Functions**, function `report-email`, method POST.
   Under HTTP Headers, press **Add auth header with service key**.
4. Press **Create webhook**.

## Test it
Open the app, report any comment, and an email titled "⚑ Maew Maps report" should arrive within a minute.
If you want to undo the test report, delete that row in Table Editor → reports.
