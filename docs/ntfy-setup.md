# Remote alerts setup (ntfy)

LurkAway can send you a **remote alert the moment your Mac is tampered with** — including a photo
of whoever is at the device and, optionally, its location. This is **off by default**. This guide
gets it working in a few minutes.

Everything here uses [ntfy](https://ntfy.sh), a free push-notification service. **LurkAway runs no
servers and has no account** — it simply posts your alert to whatever ntfy server you point it at.

---

## 1. What is ntfy?

ntfy delivers a notification to your phone, browser, or email when LurkAway posts to a **topic**
(a private channel name you choose). For the hosted server at `ntfy.sh` you need **no account and
no server setup** — publishing to a topic is free.

There are two ways to receive alerts, and you can use either or both:

| Mode | You receive | Setup on the receiving device |
|------|-------------|-------------------------------|
| **Topic (default)** | Full alert **with the intruder photo** | Open the topic URL in a browser, or install the ntfy app |
| **Email (optional)** | Text alert (details + map link, **no photo**) | Nothing — it arrives as a normal email |

The photo is always saved on your Mac regardless (Settings → Alerts → Stored evidence).

---

## 2. Pick a private topic

In **LurkAway → Settings → Alerts**, turn on **"Send a push notification on tamper"**, then press
**Generate** next to the topic field. This creates a long, random topic name.

> **Important:** the topic name is effectively a password. Anyone who knows it can see your alerts.
> Use the **Generate** button rather than a simple name like `my-mac`, and don't share the topic.

---

## 3. Receive alerts with the photo (topic mode)

Pick whichever you prefer:

**Option A — Browser (nothing to install)**
1. On your phone or another computer, open `https://ntfy.sh/<your-topic>` (use your generated topic).
2. Tap **Subscribe to topic** / allow notifications when the browser asks.
3. Keep that tab (or "Add to Home Screen" / install it as a web app) so notifications keep arriving.

**Option B — ntfy app (best experience)**
1. Install the **ntfy** app (iOS App Store, Google Play, or desktop).
2. Add a subscription to **`<your-topic>`** on the default server `ntfy.sh`.
3. Done — alerts arrive with the photo inline.

---

## 4. Receive alerts by email (optional, no app)

If you'd rather just get an email:

1. In **Settings → Alerts**, enter your address in the **Email** field.
2. That's it. On a tamper, ntfy also emails you the alert (details + map link).

Email is **text only** — the photo is not attached to the email, but it's saved on your Mac. Email
is also the most rate-limited free option (a few per day), so keep topic mode as your primary
channel and treat email as a backup.

---

## 5. Send a test

In **Settings → Alerts**, press **Send test**. Within a few seconds you should get a test
notification in your browser/app (and an email if you set one). If it arrives, you're done.

---

## 6. Troubleshooting

**Nothing arrives at all**
- Double-check the topic is spelled **identically** in LurkAway and on the receiving side.
- Re-open `https://ntfy.sh/<your-topic>` and make sure you **allowed notifications** in the browser.
- Try the **ntfy app** on cellular data — some corporate/school Wi-Fi blocks ntfy.sh.

**Browser never asked to allow notifications**
- Re-open the topic URL and check the site's notification permission (allow it).
- Some browsers only show web push after you interact with the page once.

**Email doesn't arrive**
- Check your spam folder.
- Free anonymous email is rate-limited — if you've sent several tests, wait and try later.

**Using your own (self-hosted) server**
- Put your server's URL in the **Server** field (e.g. `https://ntfy.example.com`).
- If it requires authentication, paste an access token in the **Token** field (stored in your
  macOS Keychain, never in plain settings).

---

## 7. Costs & limits

- **LurkAway is free and runs no servers** — it just posts to the ntfy server you configure.
- The hosted **`ntfy.sh` free tier covers normal use**: tamper alerts are rare, and each photo is
  only ~30–80 KB (far under ntfy's 15 MB per-attachment / 100 MB-per-visitor limits).
- Server-side attachments expire after ~3 hours, but the alert is **delivered immediately** and the
  photo is also **kept on your Mac**, so expiry doesn't lose anything.
- **Email forwarding** is the most limited free path (a few per day) — prefer topic mode.
- For unlimited volume or maximum privacy, **self-host ntfy** (free) and point the Server field at
  it. Heavy users can optionally pay for ntfy Pro. Either way, **no change is needed in LurkAway**.

---

## 8. Privacy

Enabling remote alerts is the one part of LurkAway that leaves your Mac. When enabled, a tamper
sends the notification — and, in topic mode, the photo — to the configured ntfy server over HTTPS.
With remote alerts **off** (the default), LurkAway makes no network connections at all.
