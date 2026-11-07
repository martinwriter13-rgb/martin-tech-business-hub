import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "content-type, x-job-notification-secret",
};

const escapeText = (value: unknown) => String(value ?? "").replace(/[<>]/g, "");

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });

  const expectedSecret = Deno.env.get("JOB_NOTIFICATION_WEBHOOK_SECRET");
  if (!expectedSecret || req.headers.get("x-job-notification-secret") !== expectedSecret) {
    return new Response("Unauthorized", { status: 401 });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const resendKey = Deno.env.get("RESEND_API_KEY");
  const from = Deno.env.get("NOTIFICATION_FROM");
  if (!supabaseUrl || !serviceKey || !resendKey || !from) {
    return new Response("Missing server configuration", { status: 500 });
  }

  const admin = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false } });
  const event = await req.json();
  const record = event.record ?? {};
  const oldRecord = event.old_record ?? {};
  let recipientId = "";
  let subject = "";
  let message = "";

  if (event.table === "applications" && event.type === "INSERT") {
    const { data: job, error } = await admin.from("jobs")
      .select("title, company_name, employer_id").eq("id", record.job_id).single();
    if (error || !job) return new Response("Job not found", { status: 404 });
    recipientId = job.employer_id;
    subject = "New application: " + job.title;
    message = "A new candidate has applied for " + job.title + " at " + job.company_name +
      ". Sign in to your employer dashboard to review the application.";
  } else if (event.table === "applications" && event.type === "UPDATE" && oldRecord.status !== record.status) {
    const { data: job } = await admin.from("jobs")
      .select("title, company_name").eq("id", record.job_id).single();
    recipientId = record.applicant_id;
    subject = "Application update: " + (job?.title ?? "Your application");
    const labels: Record<string, string> = {
      reviewing: "Under review",
      shortlisted: "Shortlisted",
      interview: "Interview",
      hired: "Hired",
      rejected: "Not selected",
      submitted: "Pending employer review",
    };
    message = "Your application for " + (job?.title ?? "a job") + " has been updated to: " +
      (labels[record.status] ?? record.status) + ". Sign in to the portal to view details.";
  } else if (event.table === "job_messages" && event.type === "INSERT") {
    recipientId = record.recipient_id;
    const { data: app } = await admin.from("applications")
      .select("job_id").eq("id", record.application_id).single();
    const { data: job } = app ? await admin.from("jobs")
      .select("title").eq("id", app.job_id).single() : { data: null };
    subject = "New portal message" + (job?.title ? ": " + job.title : "");
    message = "You have received a new message in the jobs portal. Preview: " +
      escapeText(String(record.body ?? "").slice(0, 180)) +
      ". Sign in to Martin Tech & Business Hub to reply.";
  } else {
    return new Response("Event ignored", { status: 200 });
  }

  const { data: userData, error: userError } = await admin.auth.admin.getUserById(recipientId);
  const email = userData?.user?.email;
  if (userError || !email) return new Response("Recipient email not found", { status: 404 });

  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { "Authorization": "Bearer " + resendKey, "Content-Type": "application/json" },
    body: JSON.stringify({ from, to: [email], subject, text: message }),
  });
  if (!response.ok) {
    const detail = await response.text();
    return new Response("Email provider error: " + detail, { status: 502 });
  }
  return new Response(JSON.stringify({ sent: true }), {
    status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
