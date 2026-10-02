import { createClient } from "npm:@supabase/supabase-js@2.117.2";
import { importPKCS8, SignJWT } from "npm:jose@6.2.12";

// Invoke every minute with x-push-secret. Credentials stay in Edge secrets.
Deno.serve(async (request: Request) => {
  const secret = Deno.env.get("PUSH_WORKER_SECRET");
  if (!secret || request.headers.get("x-push-secret") !== secret) {
    return new Response("Unauthorized", { status: 401 });
  }
  if (request.method !== "POST") return new Response("Method not allowed", { status: 405 });
  try {
    const account = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? "{}");
    const key = await importPKCS8(account.private_key, "RS256");
    const assertion = await new SignJWT({ scope: "https://www.googleapis.com/auth/firebase.messaging" })
      .setProtectedHeader({ alg: "RS256", typ: "JWT" }).setIssuer(account.client_email)
      .setAudience("https://oauth2.googleapis.com/token").setIssuedAt().setExpirationTime("1h").sign(key);
    const auth = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST", body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion }),
      signal: AbortSignal.timeout(15000),
    });
    if (!auth.ok) throw new Error("Firebase authentication failed");
    const { access_token } = await auth.json();
    const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const { data: jobs, error } = await db.rpc("claim_order_push");
    if (error) throw new Error("Unable to claim notifications");
    let sent = 0;
    // Bounded parallel delivery: leases prevent overlapping workers claiming jobs.
    await Promise.all((jobs ?? []).map(async (job: { id: number; order_id: string; token: string; lease_id: string; order_number: string }) => {
      let success = false;
      let permanent = false;
      let errorCode: string | null = null;
      try {
        const response = await fetch(`https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`, {
          method: "POST",
          headers: { Authorization: `Bearer ${access_token}`, "Content-Type": "application/json" },
          body: JSON.stringify({ message: {
            token: job.token,
            notification: { title: "Заказ готов", body: `Заказ ${job.order_number} можно забрать на кассе.` },
            data: { orderId: job.order_id },
            android: { priority: "high", ttl: "1800s", notification: { tag: `order-${job.order_id}` } },
          } }),
          signal: AbortSignal.timeout(15000),
        });
        success = response.ok;
        if (!success) {
          const payload = await response.json();
          const details = payload.error?.details ?? [];
          permanent = details.some((d: { errorCode?: string }) => d.errorCode === "UNREGISTERED");
          errorCode = `FCM ${response.status}${permanent ? " UNREGISTERED" : ""}`;
        }
      } catch (_) { errorCode = "FCM transport failure"; }
      const { error: finishError } = await db.rpc("finish_order_push", {
        p_id: job.id, p_lease_id: job.lease_id, p_success: success, p_error: errorCode, p_permanent: permanent,
      });
      if (finishError) throw new Error("Unable to acknowledge notification");
      if (success) sent++;
    }));
    return Response.json({ claimed: jobs?.length ?? 0, sent });
  } catch (_) {
    // Never log tokens, service account keys, or Firebase responses with tokens.
    return Response.json({ error: "Push worker failed; check server configuration and queue." }, { status: 500 });
  }
});
