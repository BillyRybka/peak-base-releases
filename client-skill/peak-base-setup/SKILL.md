---
name: peak-base-setup
description: Sets up Peak Base from start to finish for a business owner and moves their Obsidian notes into it. Claude does the work through Hostinger's API and the helper scripts in this skill: the server, Peak Base on it, the app on their computer, the move of their notes, and connecting Claude to their new brain. The person pays Hostinger, makes one key, and picks one password. Also gets an invited teammate onto their team's brain (app, account, their own Claude connection) and helps the owner add people and set who sees what. Use when someone says "set up my business brain", "set up Peak Base", "install Peak Base", "move my Obsidian vault to Peak Base", "connect my brain to Claude", "reset my Peak Base password", "I was invited to Peak Base", "join my team's brain", "add someone to my team", "invite my assistant", "who can see what", or asks what to do after paying Peak Systems.
---

# Peak Base setup

Your job: set up Peak Base completely and move their Obsidian notes into it. When you finish, their notes live on their own server, stay in sync with a folder on their computer, and Claude can read and write them from anywhere. They are not technical. Peak Systems built Peak Base and is their support.

**They do three things.** Pay Hostinger. Make one key on a Hostinger page and paste it into a private box. Pick their Peak Base password. Everything else is yours.

**Invited by someone else?** If they got an invite to a team's Peak Base (a link with `/invite/` in it, or someone told them to join), they need no server: skip to **Joining a team** below.

## Where this runs

This needs the **Code tab of the Claude app** (or Claude Code), because it installs an app and runs commands on their computer. In a plain chat or Cowork, tell them: "Open the Claude app, click **Code** at the top, pick your home folder, and say *set up my business brain*" (or, for an invited teammate, *I was invited to Peak Base*). Then stop.

The helpers live in this skill's `scripts/` folder. Run them with the full path:
- **Windows:** `powershell -NoProfile -ExecutionPolicy Bypass -File "<skill folder>/scripts/peak-setup.ps1" <command> ...`
- **Mac:** `bash "<skill folder>/scripts/peak-setup-mac.sh" <command> ...`

Below, `helper <command>` means that line for their computer. You know which computer it is; don't ask.

## Hard rules

- **Never handle a password or key in the chat.** Keys and passwords go into the private box (`helper ask-secret`) or are made by the helper (`make-secret`). The helpers never print them; never try to read them back, and never open `scripts/mail.key`. If they paste a key into the chat anyway: don't use it, tell them to delete it on the page where they made it and make a new one, then open the box.
- **Never buy anything.** They pay through the link below. Never call Hostinger's purchase endpoint: only the link carries Peak Systems' referral.
- **Never erase a server** (`recreate-server`) without a clear yes, and only one that is new or that they confirm is empty.
- **Never delete the `peak-base` project.** Once it runs, `deploy` only on a fresh setup or when Peak Systems says so; use `update-server` for updates.

## How you talk

- Plain words, short. "Your server", "your brain's address", "the app". Keep the technical parts to yourself, and never show them a command or its output unless something failed and you are explaining it.
- One step at a time. Say what's happening, do it, say when it's done. When you need them, say exactly what to click, then wait.
- Never guess at a screen. If what they see doesn't match, ask them to describe it or send a screenshot.
- If something fails, say what happened in a sentence and what you're doing about it. Keep going; only send them to Peak Systems after three real attempts.

## Step 0: say what's coming

Tell them, in about this many words:

> Here's how this goes. You'll do three things: pay for your server on Hostinger, make one key on a Hostinger page, and pick your Peak Base password. I do the rest, and it takes about half an hour.
>
> Along the way your computer or I will ask you to approve a few things: running my setup steps, installing the Peak Base app, and (on a Mac) letting me look in your Desktop and Documents folders for your notes. Click **Allow** or **Approve** each time. If a message says a step was blocked, open the mode menu next to the message box and pick the mode that asks before each action, then tell me to try again.
>
> Have you already paid for the Hostinger server?

Pick up from wherever they are. If the helper says a key or the server already exists, skip what's done.

## Step 1: they buy the server

Open the checkout for them (Windows `Start-Process "<link>"`, Mac `open "<link>"`):

https://www.hostinger.com/cart?product=vps%3Avps_kvm_4&period=12&referral_type=cart_link&REFERRALCODE=YZIBILLYZVMT&referral_id=01a0fd83-b6f5-72ed-b32e-b63823936a7c

Tell them exactly this:
- The plan is already picked (**KVM 4**) for **12 months**. If Hostinger offers 24 months or another deal, say no and keep 12 months.
- Leave every add-on unticked.
- To sign in, use **Continue with Google** if they have Google, so there's no new password to remember. Otherwise they make a Hostinger account and save that password in their password manager or write it down now: they sign in again in Step 2.
- **New Hostinger account:** Hostinger asks them to verify their email, and after they do it drops them on Hostinger's home page with the cart gone. Nothing is bought yet. When they say they verified, open the checkout link above again and have them pay there (the link carries the referral; the home page does not).
- Pay.
- After paying, Hostinger may show a page to set up the server (operating system, location, password, malware scanner). **Skip it or close it.** You set all of that up. If they already filled it in, that's fine too.

Wait until they say they've paid, then ask: "Do you see a Hostinger page or email saying the payment went through or the order is complete?" Signing in, verifying the email or landing on Hostinger's home page is not paying. Only a payment confirmation counts. If they're not sure, open the checkout link again and have them look: an empty cart or a page asking to pay means it isn't paid.

## Step 2: the Hostinger key

1. Open https://hpanel.hostinger.com/profile/api for them. Tell them: "Click **Generate token** (or **New token**). Name it *Peak Base*. If it asks when it expires, pick **1 year**. Then click **Copy**."
2. Tell them a small box is about to open on their screen, and to paste the key there, not in this chat. Then run:
   `helper ask-secret hostinger-token "Peak Base: Hostinger key" "Paste the key you just copied (Ctrl+V on Windows, Cmd+V on Mac), then click Save. It stays on this computer." 20`
   It answers `saved` or `cancelled`. On Windows the box takes a few seconds to appear.
3. `helper check-token`. A refusal (401) means the copy missed part of the key: ask them to copy it again and reopen the box.

## Step 3: build the server

1. `helper servers`. Their new server is the KVM 4 one, usually the newest. Nothing there? First ask whether they saw the payment confirmation. If not, they haven't paid: open the checkout link from Step 1 again and have them pay (the key they made still works). If they did see it, the purchase is still going through: check again every minute for ten minutes.
2. `helper options`. Pick the data center closest to them (the time zone helps; ask their city if it's unclear). Always pass it explicitly.
3. Set it up, depending on its `state`:
   - `initial`: `helper setup-server <id> <data center id>`. This installs Ubuntu with Docker and gives it a long random root password that only lives in their computer's password store. Nobody needs it, so they never see it.
   - `running` with an Ubuntu Docker template (they did Hostinger's setup page): `helper set-root-password <id>`, so they don't have to remember the password they picked there.
   - `running` without Docker: the server needs a fresh start. Only on a new, empty server and with their yes: `helper recreate-server <id> erase-everything`.
4. `helper wait-server <id> 20`. Setup takes 5 to 15 minutes; tell them it's a good moment for a coffee.

**When Hostinger is down or busy** (maintenance, 5xx answers, "try again"), the helper waits and retries on its own for several minutes. If it still fails: tell them Hostinger is doing maintenance, wait five minutes, and run the same command again. Do this up to three times before sending them to Peak Systems. Never say the server can't be made.

5. **The address** is the server's `hostname` (looks like `srv123456.hstgr.cloud`). From here on `<address>` means that, with no `https://`. Only if they ask for their own address (like `brain.theircompany.com`): they add an `A` record for it pointing at the server's IP where they bought the domain, and you wait until it resolves.
6. `helper firewall <id>` makes sure the web ports are open.
7. `helper deploy <id> <address>`. It installs Peak Base and gives the server a password recovery key that matches one saved on their computer (so you can reset their password later), and turns on emailed password resets when this skill carries Peak Systems' mail key. Say nothing about either unless they ask.
8. `helper containers <id>` until `server`, `postgres`, `caddy`, `backup` and `offsite` run and `init` and `migrate` have exited. If one failed, read `helper logs <id>` before trying again.
9. `helper health <address> 15`. The secure connection can take a few minutes on a new address.

Tell them in one line that their server is up.

## Step 4: the app

Tell them: "Next I install the Peak Base app. If you're asked to approve it, click Approve."

`helper install-app`. On Windows it installs and opens the app with no clicks. On a Mac it copies the app into Applications, quits an open copy first, clears the "unknown developer" block so it opens without a trip to Privacy & Security, and opens it. The app updates itself from now on.

If that step is blocked, or the Mac still says Peak Base "can't be opened": tell them to open **System Settings > Privacy & Security**, scroll down, click **Open Anyway** next to Peak Base, and confirm.

## Step 5: their account

1. `helper open-connect <address>`. A browser page opens and hands over to Peak Base with their server filled in; they confirm it.
2. Tell them: "Click **Create account**. Type your name and your email. For the password, make it in your password manager first (or write it down on paper), then paste or type it here: your password manager can't save it from this screen. Click the eye in the password box to check what you typed. This is the only password you need for Peak Base."
3. Ask which email they used (you need it if they ever forget the password). Never ask for the password.

The first account owns the server; after that, only people they invite can join.

## Step 6: move their notes in

1. Ask them to close Obsidian if it's open. Then `helper find-vaults`. Use the one marked `last_open`, or ask which if there are several. If they don't use Obsidian, skip to step 3 with a new empty folder (`Business Brain` in their home folder).
2. If `in_cloud_storage` is true (OneDrive, iCloud, Dropbox, Google Drive), move it first: those services swap files for online-only placeholders, which Peak Base would read as emptied notes. `helper move-vault "<vault>"` copies it to `Business Brain` in their home folder and compares file counts; go on only when it says `"same": true`. The old copy stays where it was. Tell them: "I copied your notes to a new folder outside OneDrive (or iCloud). Your old folder is untouched."
3. `helper open-folder "<folder>" skills` (leave off `skills` when `has_skills` is false). Peak Base asks "Open this folder in Peak Base?": tell them to click **Open and sync**. It opens the folder, turns on sync and, with skills, skill sync. Everything uploads to their server; a big vault takes a while, and that's fine.
   If nothing appears after half a minute (an older app), guide them instead: **Open existing**, pick the folder, turn on sync; then **Vault settings > General > Sync skills** if the folder has skills.
4. If you moved the folder and they want to keep Obsidian: **Manage vaults > Open folder as vault**, the new folder.

## Step 7: connect Claude to their brain

Only after sync has started (until then the sign-in page doesn't know their account yet).

1. Check for an existing connector first. Ask: "In the Claude app, open **Settings > Connectors**. Do you see **Business Brain** there?" If it's there with a different address, have them remove it. If it's there with this address, skip to 3.
2. Tell them: "Click **Add custom connector**. Name it *Business Brain*. For the address, copy this whole line:" and put the address alone on its own line, nothing else in it:

   ```
   https://<address>/api/mcp
   ```

   "Click Add, then Connect. A page opens: sign in with your Peak Base email and password, then click Allow." The connector then works in every Claude chat, Cowork and the phone app.
3. Test it. If its tools have reached this session, call `start_session`, then search their notes for something you saw in their folder names. Otherwise ask them to open a new chat and ask "What do my notes say about <a real topic from their folders>?". It should answer from their notes.

## Step 8: close

Two lines, no more:

> Your business brain is live at `<address>`, and Claude can read and write your notes from any chat. The app and server update and back up on their own; if you ever forget your password, just ask me to reset it.

## Later, when they ask

**Forgot their Peak Base password.** If "Forgot password?" shows on the sign-in screen, that emails them a link. Otherwise: `helper reset-password <address> <their email>`. A private box asks for the new password twice; the server sets it with the recovery key saved on this computer. On another computer the key isn't there: Peak Systems can reset it. A teammate who forgot theirs: on the owner's computer, run the same command with the teammate's email; the owner picks a new password in the box and gives it to the teammate privately (never in this chat).

**Backups to their Google Drive.** The server backs up every night and keeps 14 days. To also keep 30 days in their Drive:
1. Install rclone: Windows `winget install Rclone.Rclone`, Mac `brew install rclone` (no Homebrew? Peak Systems can help).
2. `rclone authorize "drive"`. A browser opens; they sign in to Google and allow access.
3. The window prints a block starting with `{"access_token"`. They copy it themselves into hPanel: **VPS > Docker Manager > peak-base > Environment**, `GDRIVE_TOKEN` = that block, then redeploy. It never goes in this chat.

**Their team.** See **Adding people** below.

**Updates.** The app updates itself. Server: `helper update-server <id>` (find the id with `helper servers`).

**Restoring a backup:** Peak Systems handles it.

## Adding people (the owner)

1. **Invite.** In Peak Base: **Vault settings > Members and access > Invite people**. They type the person's email, pick **Member** (most people) or **Admin** (can invite people and change who sees what), and pick how much the person sees to start: **Can edit everything**, **Can view everything** or **No access**. Then **Copy link** next to the invitation and send it however they like (text, email, Slack). The link works for 7 days. The dialog also shows a join code; the link is simpler.
2. **Tell them what to send with it:** "Install the Peak Base setup skill in your Claude app and say *I was invited to Peak Base*, then paste this link. Or follow the guide." The guide for people without Claude: https://github.com/BillyRybka/peak-base-releases/blob/main/docs/join-your-team.md
3. **Who sees what**, on the same page, in plain words:
   - The **Everyone** row is the starting point for every member: Can edit, Can view or No access.
   - Each person can get their own level, and theirs wins, for them only.
   - For folder by folder, click the person, open **Access**, and drag folders between **Can edit**, **Can view** and **No access**. Each move applies right away.
   - The **New members** row decides what someone who joins later sees of the notes that already exist.
   - **No access means nobody**, the owner included, until someone gives access back. If they close off the whole vault, give themselves access first.
   - When someone loses access, those notes leave that person's computer. They stay on the server for everyone else.
4. **Or let Claude do it.** With the Business Brain connector, an owner or admin can just ask: "Share the Sales folder with Jane, view only" or "What can Mike see?". Use the brain's `list_resource_access`, `manage_access`, `get_access_default` and `set_access_default` tools. Say what will change and get their yes before `manage_access` or `set_access_default`, and before anything that takes access away.
5. **Removing someone:** click the **...** next to their name, then **Remove**. Their access ends on all their computers at once.

Each person connects Claude with their own sign-in, so their Claude sees exactly what they can see, and nothing more.

## Joining a team (an invited teammate)

They need no server and no Hostinger: the owner already has one. **They do two things:** open the invite link, and pick their Peak Base password. Tell them that first, then:

1. **The link.** Ask them to paste the invite link here (it's an invitation, not a password, so the chat is fine). Their team's `<address>` is the part between `https://` and `/invite/`. No link? Ask the person who invited them to send one from **Members and access**.
2. **The app.** Tell them: "Next I install the Peak Base app. If you're asked to approve it, click Approve." Then `helper install-app`, with the same fallback as Step 4 if the Mac blocks it. If its answer says team vaults go in `Peak Base Vaults` in their home folder, their Documents folder is in iCloud or OneDrive and the notes are kept out of it; say nothing unless they ask.
3. **Join.** Open the link for them (Windows `Start-Process "<link>"`, Mac `open "<link>"`). Tell them: "On this page, skip step 1 (the app is installed), and click **Open Peak Base**. If Peak Base asks whether to use this server, say yes."
4. **Their account.** Tell them: "Click **Create account** and use the exact email the invitation names; it's on the page you just saw. Make the password in your password manager first (or write it down), then paste or type it, and click the eye to check it." If they already have an account on this team's server, they sign in instead. Ask which email they used; never ask for the password.
5. **Their notes.** They land in the team's vault and it downloads to their computer. A big vault takes a few minutes; let it finish.
6. **Connect Claude** exactly as in Step 7, with the team's address. They sign in with their own Peak Base email and password. If Claude asks to use a Business Brain tool, **Always allow** is fine.
7. **Close**, two lines: "You're in your team's brain, and Claude can read and write the notes you have access to from any chat. If you can't see a folder you need, ask the person who invited you."

If the link says the invitation expired, was already used, or was withdrawn: they ask the owner for a new one. If it says already used and it was them, they just sign in.

## For Peak Systems

- `scripts/mail.key` (not in the public download) turns on emailed password resets: Resend sends from Peak Systems' `brain.peaksystems.io` domain. Make it with `helper ask-secret resend-api-key "Resend key" "Paste the Peak Base client servers key"`, then `helper pack-mail-key "Peak Base <reset@brain.peaksystems.io>"`.
- First-run checklist for the server path: `docs/first-server-run.md` in the releases repo.
