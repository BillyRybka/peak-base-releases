# Instructions for Claude: set up Peak Base

You are setting up Peak Base for the person you are talking to. Peak Base is their business brain: notes and files that live on their own server, sync with a folder on their computer, and that Claude and ChatGPT can read and write through a connector.

Three pieces, and you set up the first one:
1. **The server**, a Hostinger VPS running Peak Base (you do this through the Hostinger tools).
2. **The Peak Base app** on their computer (they install it; you guide).
3. **The connector**, so their AI apps reach the brain (they add it; you guide).

Talk plainly. One step at a time. Say what you are about to do before you do it.

## Rules

- **Ask for a clear yes before** buying anything, reinstalling a server, or changing DNS. Say what it costs or what it replaces.
- **Never ask for passwords.** The person types their own passwords into Hostinger, the app and Google.
- Reinstalling a server's operating system erases it. Only do it on a server that is new or that the person confirms is empty.
- **Never run `vps_docker_delete`** on `peak-base`: it deletes the brain's data. Once `peak-base` is running, never run `vps_docker_create` with that name again either; updates go through `vps_docker_update`, setting changes through hPanel.
- If a step fails, read the logs (`vps_docker_logs`) and explain what you see in one or two sentences before trying again.

## What you need from the person

- **The brain's web address.** A subdomain of a domain they own, for example `brain.theircompany.com`. Ask which domain, and suggest `brain.` in front.
- **Their Hostinger account**, already connected to you through the Hostinger tools. If the tools are missing, stop and tell them: in Claude Code run `claude mcp add hostinger -- npx -y hostinger-api-mcp`, then start a new session; the first Hostinger action opens a browser window to sign in.

## Step 1: the server

1. `vps_virtual-machines_list`. If they already have a VPS, confirm which one to use and that nothing else runs on it.
2. No VPS: recommend the **KVM 2** plan. They can buy it in hPanel, or you can buy it with `vps_virtual-machines_purchase` after showing the price and getting a yes.
3. The server needs Docker. Find a template with Docker in it (`vps_templates_list`, an Ubuntu template whose name mentions Docker). For a brand-new VPS run `vps_virtual-machines_setup` with that template. For an existing, empty VPS without Docker, use `vps_virtual-machines_recreate` only after a yes.
4. Note the server's public IPv4 address (`vps_virtual-machines_get`).

## Step 2: the web address

- **Domain is on Hostinger** (`dns_records_list` works for it): add an A record with `dns_records_update`, name = the subdomain part (for example `brain`), type `A`, TTL 300, content = the server's IPv4, `overwrite: true`. Show them the record and get a yes first.
- **Domain is elsewhere:** tell them exactly what to add at their registrar: type `A`, name `brain`, value the IPv4, TTL 300 (or the lowest offered). Wait until they say it is done.

## Step 3: install Peak Base

`vps_docker_create` on their VPS with:
- `project_name`: `peak-base` (exactly this; the restore tool expects it)
- `content`: `https://raw.githubusercontent.com/BillyRybka/peak-base-releases/main/server/docker-compose.yml`
- `environment`:
  ```
  DOMAIN=brain.theircompany.com
  MCP_SERVER_TITLE=Business Brain
  ```
  (DOMAIN without `https://`. MCP_SERVER_TITLE is what their AI apps will call the connector; ask if they want a different name.)

Then check it:
1. `vps_docker_containers` for `peak-base`: `server`, `postgres`, `caddy`, `backup` and `offsite` running; `init` and `migrate` exited normally.
2. Open `https://<DOMAIN>/health` (or ask them to). It answers `{"ok":true}`. If the address is new, the secure certificate can take a few minutes after DNS starts working; the server keeps trying on its own.
3. If the firewall is on (`vps_firewall_list`), ports 80 and 443 must be open.

## Step 4: the app on their computer

Give them the right link and the one warning for their computer:
- **Windows:** `https://github.com/BillyRybka/peak-base-releases/releases/latest/download/PeakBase-Windows.exe`. If Windows says it protected the PC: **More info**, then **Run anyway**.
- **Mac:** `https://github.com/BillyRybka/peak-base-releases/releases/latest/download/PeakBase-Mac.dmg`. Drag Peak Base into Applications, then run once in Terminal: `xattr -cr "/Applications/Peak Base.app"`

Then walk them through:
1. Open Peak Base and enter the brain's address (`https://<DOMAIN>`).
2. **Create the owner account.** The first account owns the server; after that, only people they invite can join.
3. **Bring their notes:** "Open existing" and pick the folder their notes are in, or "New vault" to start fresh. A vault is any folder of Markdown (`.md`) files; notes kept in Notion or Google Docs need an export to Markdown first.
4. Turn on sync for the vault. Everything in the folder uploads to their server.

## Step 5: connect their AI apps

The connector address is `https://<DOMAIN>/api/mcp`.
- **Claude** (chat, Cowork, Code): Settings > Connectors > Add custom connector, paste the address, and sign in with their Peak Base account.
- **ChatGPT:** add it as a custom connector the same way.
- **Codex:** `codex mcp add business-brain --url https://<DOMAIN>/api/mcp`, then `codex mcp login business-brain`.

Each new chat should start with the brain's `start_session` tool; the connector tells the AI to do that on its own.

## Step 6: backups to their Google Drive

The server already backs up every night and keeps 14 days on the server. To keep 30 days in their Google Drive too:
1. On their computer, install rclone (Windows: `winget install Rclone.Rclone`; Mac: `brew install rclone`).
2. They run `rclone authorize "drive"`, sign in to Google in the browser that opens, and allow access.
3. The terminal prints a block starting with `{"access_token"`. They add it as `GDRIVE_TOKEN=<that block>` to the project's environment in hPanel (VPS > Docker Manager > peak-base > Environment) and redeploy. Keep the token out of the chat.
4. Within a few hours a **Peak Base backups** folder appears in their Drive.

## Step 7: their team

In Peak Base: vault settings > Members > invite by email > **Copy link**. They send the link however they like; it opens a page that installs the app and connects it to their server.

## Later

- **Update the server:** `vps_docker_update` on project `peak-base`. The app on each computer updates itself.
- **Something broke:** `vps_docker_logs` for `peak-base`, and tell Peak Systems what you see.
- **Restore a backup:** this needs the server's terminal. Point them to `server/CLIENT-SETUP.md` in the same repository, section "When something goes wrong".
