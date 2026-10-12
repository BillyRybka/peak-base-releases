---
name: peak-base-setup
description: Sets up Peak Base from start to finish for a business owner and moves their Obsidian notes into it. Claude does the work: the Hostinger server, Peak Base on that server, the app on their computer, the move of their notes, and connecting Claude to their new brain. The person only buys the server, approves sign-ins, clicks Install and picks their own password. Use when someone says "set up Peak Base", "set up my business brain", "install Peak Base", "move my Obsidian vault to Peak Base", "move my notes into my brain", "connect my brain to Claude", or asks what to do after buying the Peak Base server plan.
---

# Peak Base setup

Your job: set up Peak Base completely and move their Obsidian notes into it. When you finish, their notes live on their own server, stay in sync with a folder on their computer, and Claude can read and write them from anywhere. They are not technical. Peak Systems built Peak Base and is their support.

**You do the work.** They do only the five things that have to be them:
1. Buy the server through the link (it's their account and their card).
2. Approve Hostinger's sign-in when the browser asks.
3. Click through the app installer.
4. Pick their own Peak Base password.
5. Approve the Business Brain sign-in when the browser asks.

Everything else is yours: the server, Peak Base on it, the address, checking it's live, finding and preparing their notes, telling them exactly where to click and what to paste.

## How you talk

- Open with the five things above in plain words, then ask if they're on Mac or Windows and whether they've bought the server yet. Pick up from wherever they are.
- One step at a time. Say what's happening, do it, tell them when it's done. When you need them, say exactly what to click or paste, then wait.
- No jargon. "Your server", "your brain's address", "the app". Keep the technical parts to yourself.
- Never guess at a screen. If what they see doesn't match, ask them to describe it or share a screenshot.
- If something fails, say what happened in a sentence or two and what you'll try next. If it's still stuck, tell them Peak Systems can help and what to tell them.

## Hard rules

- **Never buy anything.** They buy the server through the link below. Never use `vps_virtual-machines_purchase`: only the link carries Peak Systems' referral.
- **Never ask for or handle passwords.** They type their own into Hostinger, Peak Base and Google.
- **Never erase a server** (`vps_virtual-machines_recreate`, or an operating system change in hPanel) without a clear yes, and only on a server that is new or that they confirm is empty.
- **Never delete the `peak-base` project**, and once it runs never create it again under that name. It holds their brain.
- The Google Drive token (later section) never goes in the chat.

## What you can do yourself

- **Hostinger:** through Hostinger's hosted connector (step 2). It gives you `search`, `execute` and `multi-execute`. Run each operation named below through `execute` as `{"operation": "<name>", "params": {...}}`; `search` the operation's name first to get its exact parameters.
- **Their computer:** if you can run commands (Claude Code, or a Claude app session working in a folder), you download and open the installer, find and prepare their notes folder, and check the server yourself. On Windows, start programs with `Start-Process explorer.exe "<file>"` so they open as a normal app. In a plain chat, give them each click and paste instead.
- **Their notes folder:** if you're already working inside their Obsidian vault, that's the folder. Note its full path at the start.

## Step 1: they buy the server

Send them this link:

https://www.hostinger.com/cart?product=vps%3Avps_kvm_4&period=12&referral_type=cart_link&REFERRALCODE=YZIBILLYZVMT&referral_id=01a0fd83-b6f5-72ed-b32e-b63823936a7c

Tell them: keep the plan as it is (KVM 4). If checkout asks what to install, choose **Ubuntu with Docker**. If it asks for a server password, they choose it and keep it to themselves. Wait until they say the purchase went through.

## Step 2: connect to their Hostinger account

- Claude app: have them open **Settings > Connectors > Add custom connector**, name `Hostinger`, address `https://mcp.hostinger.com`. A browser window opens; they sign in to Hostinger and approve.
- Claude Code: run `claude mcp add --transport http hostinger https://mcp.hostinger.com`; they approve in the browser that opens.

If it won't connect, use the hPanel clicks given under each step instead.

## Step 3: build the server

1. `vps_virtual-machines_list` to find the server. If something else already runs on it, confirm it's the right one and empty.
2. If it has no operating system yet: `vps_templates_list`, pick the Ubuntu template whose name mentions Docker, `vps_virtual-machines_setup` with it. Wait for it to finish.
3. **The address:** use the one Hostinger gave the server, from `vps_virtual-machines_get` (looks like `srv123456.hstgr.cloud`). No domain setup needed. From here on `<address>` means that, without `https://`. Only if they ask for their own address (like `brain.theircompany.com`): domain on Hostinger, show them the record (type `A`, name `brain`, value the server's IP, TTL 300), get a yes, `dns_records_update` with `overwrite: true`; domain elsewhere, tell them exactly what to add where they bought it and wait.
4. **Put Peak Base on it:** `vps_docker_create` with `project_name` `peak-base` (exactly this), `content` `https://raw.githubusercontent.com/BillyRybka/peak-base-releases/main/server/docker-compose.yml`, and `environment`:
   ```
   DOMAIN=<address>
   MCP_SERVER_TITLE=Business Brain
   ```
5. `vps_docker_containers` for `peak-base`: `server`, `postgres`, `caddy`, `backup` and `offsite` running; `init` and `migrate` finished. If one failed, read `vps_docker_logs` before trying again.
6. **Check it's live:** `https://<address>/health` answers ok (fetch it yourself if you can). The secure connection can take a few minutes on a new address; wait and retry. Still failing after ten minutes: `vps_firewall_list`, and ports 80 and 443 must be open.

Without the connector, guide them in hPanel: **VPS**, their server (the overview shows the address), **Docker Manager**, **Compose from URL**, paste the compose address above, project name `peak-base`, add `DOMAIN` and `MCP_SERVER_TITLE` as above, **Deploy**. If Docker Manager offers to install Docker, let it.

Tell them when the server is up, in one line.

## Step 4: the app on their computer

**Windows.** With commands: download `https://github.com/BillyRybka/peak-base-releases/releases/latest/download/PeakBase-Windows.exe` to their Downloads folder and open it with `Start-Process explorer.exe "<path>"`. They click through the installer. In chat: give them the link; if Windows says it protected the PC, **More info**, then **Run anyway**.

**Mac.** With commands: download `https://github.com/BillyRybka/peak-base-releases/releases/latest/download/PeakBase-Mac.dmg`, mount it (`hdiutil attach`), copy `Peak Base.app` into `/Applications`, detach, then run `xattr -cr "/Applications/Peak Base.app"`. In chat: link, drag into Applications, then that one Terminal line (a Mac blocks apps from makers it doesn't know yet; this tells it Peak Base is fine).

The app updates itself from now on.

## Step 5: their account

Open `https://<address>/open/connect` (or send them the link). It opens Peak Base with their server already filled in; they confirm. Then they create their account with their own password. The first account owns the server; after that, only people they invite can join.

## Step 6: move their notes in

1. **Find the folder.** Use the path you noted at the start. Otherwise: in Obsidian, the vault name at the bottom left, **Manage vaults**, the menu next to their vault, **Show in system explorer** (Windows) or **Reveal in Finder** (Mac).
2. **Get it out of cloud storage.** If the path has `OneDrive`, `iCloud`, `Mobile Documents`, `Dropbox` or `Google Drive` in it, move it first: those services swap files for online-only placeholders, which Peak Base would read as emptied notes. On Windows, OneDrive often holds Documents and Desktop without people knowing. Copy the whole vault to a plain folder (Windows: `C:\Users\<them>\Business Brain`, with `robocopy "<vault>" "<new>" /E`; Mac: `~/Business Brain`, with `ditto`), compare file counts, then have them point Obsidian at the new folder (**Manage vaults > Open folder as vault**). Leave the old copy alone; they can delete it later.
3. In Peak Base: **Open existing**, pick the folder, turn on **sync**. Everything uploads to their server; a big vault takes a while.
4. If the folder has `.claude/skills`, turn on **Vault settings > General > Sync skills** so their skills reach the brain too.

They can keep using Obsidian on the same folder.

## Step 7: connect Claude to their brain

- Claude app: **Settings > Connectors > Add custom connector**, name `Business Brain`, address `https://<address>/api/mcp`. They sign in with their Peak Base account.
- Claude Code: `claude mcp add --transport http business-brain https://<address>/api/mcp`, and they sign in when asked.

ChatGPT connects the same way. Then, in a new chat, ask Claude something about their notes to show it works.

Close with a short recap: their brain's address, that the app and server back up and update on their own, and that Peak Systems is there for anything else.

## Later, when they want it

**Backups to their Google Drive.** The server backs up every night and keeps 14 days. To also keep 30 days in their Drive:
1. Install rclone: Windows `winget install Rclone.Rclone` (then a new Terminal window), Mac `brew install rclone` (no Homebrew? Peak Systems can help).
2. `rclone authorize "drive"`. A browser opens; they sign in to Google and allow access.
3. Terminal prints a block starting with `{"access_token"`. They copy it themselves into hPanel: **VPS > Docker Manager > peak-base > Environment**, `GDRIVE_TOKEN` = that block, then redeploy. It never goes in this chat.
4. Within a few hours a **Peak Base backups** folder appears in their Drive.

**Their team.** In Peak Base: **Vault settings > Members and access > Invite people**, then **Copy link**, sent however they like. The access board on the same page sets what each person sees: **Can edit**, **Can view** or **No access**.

**Updates.** The app updates itself. Server: `vps_docker_update` on `peak-base`, or redeploy the project in hPanel's Docker Manager.

**Forgotten password or restoring a backup:** Peak Systems handles these.
