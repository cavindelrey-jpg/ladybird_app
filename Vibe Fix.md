# Vibe Fix

## Task Progress
- [ ] Review the Vibe Fix document
- [ ] Identify areas for improvement
- [ ] Implement suggested fixes
- [ ] Test the changes
- [ ] Document the results

## Task Progress
- [ ] Review the Vibe Fix document
- [ ] Identify areas for improvement
- [ ] Implement suggested fixes
- [ ] Test the changes
- [ ] Document the results
### Full-Stack Production Audit & Hardening Template for Vibe-Coded (Vite) Apps

AI coding tools (Cursor, Bolt, v0, Lovable, Replit) are great at shipping a working UI fast — but they routinely skip the structural engineering work that keeps an app secure, fast, and stable in production. This template turns a "vibe-coded" app into something a full-stack developer would actually ship.

Treat the Vite app as **UI only**. Move all sensitive logic behind a real backend boundary.

---

## 1. Top 8 Vibe-Coding Vulnerabilities

1. **Exposed secrets via `VITE_` env vars** — Vite inlines any `VITE_`-prefixed variable into the public JS bundle. Secret keys (Stripe secret, OpenAI, Supabase `service_role`) placed here are visible to anyone in DevTools.
2. **Missing database indexes** — AI generators write `CREATE TABLE` statements but rarely index foreign keys, `status` columns, or filter fields, causing full table scans as data grows.
3. **Row-Level Security (RLS) flaws** — Tables often ship with RLS disabled (public read/write by default), and policies written as `USING (auth.uid() = user_id)` re-evaluate per row instead of using the optimized `USING ((select auth.uid()) = user_id)` pattern.
4. **Frontend-only authorization** — Guards like `<ProtectedRoute>` live only in the UI; without server-side checks, an attacker can call the API directly and bypass them.
5. **Unconstrained mass assignment** — Forwarding entire request bodies into DB updates (e.g. `db.users.update(req.body)`) lets users inject fields like `"is_admin": true`.
6. **Vite build/asset path failures** — Missing or wrong `base` config breaks JS/CSS asset loading on custom domains or subpaths.
7. **Exposed source maps & debug logs** — Default builds can ship `.map` files and `console`/`debugger` statements, letting attackers reconstruct original source code.
8. **Dependency hallucination ("slopsquatting")** — AI models sometimes import non-existent or abandoned packages; attackers publish malicious packages under these hallucinated names.

---

## 2. Copy-Paste Audit Checklist

```
[ ] SECRETS
  - No VITE_ / NEXT_PUBLIC_ / REACT_APP_ vars contain secret keys, service_role, DB passwords, JWT secrets
  - .env / .env.local are gitignored; no secrets in git history
  - Public config values (Supabase URL, Stripe publishable key) are non-sensitive
  - All privileged third-party calls run server-side only

[ ] AUTHENTICATION
  - Every non-public route/endpoint verifies the session server-side
  - No reliance on frontend-only redirects or hidden UI for protection
  - Tokens/sessions stored securely (prefer httpOnly cookies over localStorage)

[ ] AUTHORIZATION / ACCESS CONTROL
  - Ownership checks on every READ, UPDATE, DELETE (not just "is logged in")
  - No IDOR: changing a resource ID doesn't expose another user's data
  - Admin/privileged endpoints are restricted
  - Multi-tenant isolation enforced if applicable

[ ] DATABASE
  - RLS enabled on every table holding user/tenant data, policies tested with the anon key
  - Policies use wrapped subqueries: ((select auth.uid()) = user_id)
  - Indexes on all foreign keys, created_at/sort columns, and hot filter columns
  - Foreign keys enforce referential integrity (ON DELETE CASCADE/RESTRICT)
  - Privilege fields (role, is_admin, plan) sit on locked tables, not reachable by generic UPDATE
  - No service_role usage from the client
  - Parameterized queries / ORM only — no string-concatenated SQL

[ ] INPUT & OUTPUT VALIDATION
  - Server-side schema validation on every payload (Zod, Yup, Valibot)
  - No unsanitized dangerouslySetInnerHTML / raw HTML injection (XSS)
  - Generic error messages to clients; no stack traces leaked

[ ] RATE LIMITING & ABUSE
  - Login, signup, password reset, and public write endpoints throttled
  - Expensive/LLM endpoints have resource-consumption limits

[ ] NETWORK & HEADERS
  - CORS restricted to an explicit allow-list (no wildcard + credentials)
  - CSRF protection on cookie-based sessions
  - CSP, HSTS, X-Frame-Options (or frame-ancestors), X-Content-Type-Options set

[ ] FILE UPLOADS
  - Type/size restrictions enforced
  - Stored outside the web root, served via signed URLs
  - Virus/malware scanning if applicable

[ ] VITE BUILD & DEPLOYMENT
  - `base` correctly configured for target hosting (Vercel, Netlify, S3, Cloudflare)
  - Production build disables source maps (`build.sourcemap: false`)
  - console/debugger statements stripped from production output
  - Correct env vars baked in per environment (dev/staging/prod)
  - SPA routing fallback configured on the host/reverse proxy

[ ] OPERATIONAL HYGIENE
  - `npm audit` / `pnpm audit` returns 0 high/critical vulnerabilities
  - Every package verified as real and actively maintained (no hallucinated deps)
  - Global error handlers log to a monitoring service (Sentry, LogRocket) without leaking details to users
  - Auth failures, privilege escalations, and anomalies logged + alerted
  - Cost alerts configured on metered external APIs
  - Pagination on list endpoints; no N+1 queries
  - Basic tests on critical paths
```

---

## 3. Code Patterns: Vibe-Coded vs. Full-Stack

### Pattern 1 — Database Schema & RLS (Postgres/Supabase)

**❌ Vibe-coded (vulnerable, unindexed):**
```sql
CREATE TABLE posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  title TEXT,
  content TEXT
);
-- RLS left disabled; anon key can read/write everything
```

**✅ Full-stack (production-ready):**
```sql
CREATE TABLE posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE posts ENABLE ROW LEVEL SECURITY;

CREATE INDEX idx_posts_user_id ON posts(user_id);
CREATE INDEX idx_posts_created_at ON posts(created_at DESC);

CREATE POLICY "Users can manage own posts" ON posts
  FOR ALL TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);
```

### Pattern 2 — Third-Party API Calls (Stripe/OpenAI)

**❌ Vibe-coded (secret leak):**
```ts
// src/components/PaymentButton.tsx
import Stripe from 'stripe';

// DANGER: exposes the secret key in the browser bundle
const stripe = new Stripe(import.meta.env.VITE_STRIPE_SECRET_KEY);

export function PaymentButton() {
  const handlePay = async () => {
    const session = await stripe.checkout.sessions.create({ /* ... */ });
    window.location.href = session.url!;
  };
  return <button onClick={handlePay}>Checkout</button>;
}
```

**✅ Full-stack (secure backend proxy):**
```ts
// src/components/PaymentButton.tsx (frontend — safe)
export function PaymentButton() {
  const handlePay = async () => {
    const res = await fetch('/api/create-checkout-session', { method: 'POST' });
    const { url } = await res.json();
    window.location.href = url;
  };
  return <button onClick={handlePay}>Checkout</button>;
}

// api/create-checkout-session.ts (server/edge — private)
import Stripe from 'stripe';
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!);

export async function POST(req: Request) {
  // verify auth server-side before processing
  const session = await stripe.checkout.sessions.create({ /* ... */ });
  return Response.json({ url: session.url });
}
```

### Pattern 3 — Vite Production Build

**❌ Vibe-coded (default config):**
```ts
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
});
```

**✅ Full-stack (hardened config):**
```ts
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  build: {
    sourcemap: false, // don't leak source in production
    terserOptions: {
      compress: {
        drop_console: true,
        drop_debugger: true,
      },
    },
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['react', 'react-dom'],
        },
      },
    },
  },
  base: '/', // set to match your hosting path
});
```

---

## 4. Suggested Fix Order (Highest Risk First)

1. **Secrets** — pull anything sensitive out of the client bundle and git history
2. **Authentication** — enforce it server-side everywhere
3. **Authorization / ownership / RLS** — close IDOR and privilege-escalation gaps
4. **Input validation & injection prevention**
5. **Rate limiting / CORS / security headers**
6. **File handling**
7. **Logging & monitoring**
8. **Deployment hygiene & indexes**
9. **Refactoring & tests**

Most real-world incidents in AI-generated apps trace back to the first three items on this list — start there.
