# First real server run: checklist

The setup skill's server path (Hostinger API calls that create and change a server) has not run on a real server yet. Everything else was tested on Windows on 2026-11-02. Do this once, on Billy's own Hostinger account with a throwaway KVM plan or with the next client, and tick each line. Fix the skill or the helper wherever a line fails.

Never point this at the NAS Business Brain (business-brain.tail8a2137.ts.net).

## Before

- [ ] The app release that has the "Open this folder in Peak Base?" link (1.0.7 or later) is out. Older apps ignore `open-folder` and the skill falls back to clicks.
- [ ] The server image with `/api/peak/recover-password` is published (`build-image.sh`), so `PASSWORD_RECOVERY_KEY` does something.
- [ ] If email resets are wanted: Resend domain `brain.peaksystems.io` verified, key "Peak Base client servers" made with sending access for that domain only, `mail.key` packed into the private skill download (see SKILL.md, For Peak Systems).

## Checkout and key

- [ ] The checkout link opens on KVM 4, 12 months. Note any upsell screens and their button words; put them in Step 1 if they differ.
- [ ] Note what Hostinger shows right after paying. Can the setup page be skipped? Does the server stay in state `initial` if it is? Put the exact words in Step 1.
- [ ] hPanel > Profile > API: note the real button names and expiry choices; fix Step 2.
- [ ] `ask-secret hostinger-token`: the box opens in front of the Claude app, paste works, `check-token` says ok.

## Server

- [ ] `servers` shows the new server; note its `state`, `hostname` and `template`.
- [ ] `options` lists data centers and finds an "Ubuntu ... Docker" template.
- [ ] `setup-server <id> <dc>` is accepted (password rules: 12+ characters, upper, lower, number; the helper makes 24). If Hostinger refuses the password as leaked or weak, note the message.
- [ ] `wait-server` ends at `running unlocked`. Note how long it took.
- [ ] `firewall <id>`: note whether a new server has a firewall at all.
- [ ] `deploy <id> <address>`: Hostinger accepts the environment as KEY=value lines (check `DOMAIN` reached the server: `health` answers, and the connector address works). If the `EMAIL_FROM` quotes break it, note the error.
- [ ] `containers <id>` shows server, postgres, caddy, backup, offsite running; init and migrate exited.
- [ ] `health <address>` answers ok over https.
- [ ] `set-root-password` on a server set up through Hostinger's own page: accepted.

## App and account

- [ ] Windows: `install-app` installs silently and opens the app. Mac: the app lands in Applications and opens with no Privacy & Security step.
- [ ] `open-connect <address>`: the app opens with the server filled in.
- [ ] Sign up: the eye button shows the password; the password manager offers to save it.
- [ ] `/api/auth-methods` on the new server says `passwordRecovery: true` (and `passwordReset: true` with the mail key).
- [ ] `reset-password <address> <email>`: the box asks twice, the old password stops working, the new one works.
- [ ] With the mail key: "Forgot password?" sends an email from `reset@brain.peaksystems.io` and the link works.

## Notes and connector

- [ ] `find-vaults` finds their vault and flags OneDrive or iCloud.
- [ ] `move-vault` copies with matching counts (Mac with iCloud: online-only files download first).
- [ ] `open-folder <folder> skills`: the app asks, then opens, syncs and turns on skill sync.
- [ ] The custom connector signs in only after the account exists, and the test question answers from their notes.

Time the whole run. Target: under 30 minutes of their time.
