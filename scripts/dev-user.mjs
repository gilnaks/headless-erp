#!/usr/bin/env node
// Creates (or resets) a pre-confirmed Auth user on the project in .env.local, bypassing confirmation emails.
// Dev/test only: uses SUPABASE_SERVICE_ROLE_KEY. Never point it at production.
//
//   node scripts/dev-user.mjs <email> <password> [first_name] [last_name]
//   node scripts/dev-user.mjs --delete <email>
//   node scripts/dev-user.mjs --magic-link <email>   # prints a /auth/callback?token_hash=... URL

import { readFileSync } from "node:fs";

const env = Object.fromEntries(
    readFileSync(new URL("../.env.local", import.meta.url), "utf8")
        .split(/\r?\n/)
        .filter((l) => l && !l.startsWith("#") && l.includes("="))
        .map((l) => [l.slice(0, l.indexOf("=")).trim(), l.slice(l.indexOf("=") + 1).trim()]),
);

const url = env.VITE_SUPABASE_URL ?? env.NEXT_PUBLIC_SUPABASE_URL;
const key = env.SUPABASE_SERVICE_ROLE_KEY;
const appUrl = env.APP_URL ?? "http://localhost:3000";
if (!url || !key) throw new Error("VITE_SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set in .env.local");

const headers = { apikey: key, Authorization: `Bearer ${key}`, "Content-Type": "application/json" };

async function api(path, init = {}) {
    const res = await fetch(`${url}/auth/v1${path}`, { ...init, headers });
    const body = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(`${init.method ?? "GET"} ${path}: ${res.status} ${body.msg ?? body.message ?? JSON.stringify(body)}`);
    return body;
}

async function findUser(email) {
    for (let page = 1; page < 50; page++) {
        const { users } = await api(`/admin/users?page=${page}&per_page=200`);
        const user = users.find((u) => u.email === email.toLowerCase());
        if (user || users.length < 200) return user;
    }
    return undefined;
}

const [flag, ...rest] = process.argv.slice(2);

if (flag === "--delete") {
    const user = await findUser(rest[0]);
    if (user) await api(`/admin/users/${user.id}`, { method: "DELETE" });
    console.log(user ? `deleted ${rest[0]}` : `no user ${rest[0]}`);
} else if (flag === "--magic-link") {
    const link = await api("/admin/generate_link", { method: "POST", body: JSON.stringify({ type: "magiclink", email: rest[0] }) });
    const tokenHash = link.hashed_token ?? link.properties?.hashed_token;
    console.log(`${appUrl}/auth/callback?token_hash=${tokenHash}&type=magiclink&next=%2F`);
} else {
    const [email, password, first_name = "Dev", last_name = "User"] = [flag, ...rest];
    if (!email || !password) throw new Error("usage: node scripts/dev-user.mjs <email> <password> [first_name] [last_name]");
    const existing = await findUser(email);
    const payload = { email, password, email_confirm: true, user_metadata: { first_name, last_name } };
    const user = existing
        ? await api(`/admin/users/${existing.id}`, { method: "PUT", body: JSON.stringify(payload) })
        : await api("/admin/users", { method: "POST", body: JSON.stringify(payload) });
    console.log(`${existing ? "updated" : "created"} ${user.email} (${user.id})`);
}
