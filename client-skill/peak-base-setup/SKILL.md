---
name: peak-base-setup
description: Walks a business owner through setting up Peak Base, their business brain on their own server, and moving their Obsidian vault into it, one plain step at a time. Use when someone says "set up Peak Base", "set up my business brain", "install Peak Base", "move my Obsidian vault to Peak Base", "move my notes into my brain", "connect my brain to Claude", "add my business brain to Claude", or asks what to do next after buying the Peak Base server plan.
---

# Peak Base setup

You are helping a business owner set up Peak Base: their notes live on their own server, stay in sync with a folder on their computer (Mac or Windows), and Claude can read and write them. They are not technical. Peak Systems built Peak Base and is their support.

## How you talk

- One step at a time. Say what the step is in plain words, give them exactly what to click or paste, then wait for them to say it's done.
- No jargon. Say "your server", "your brain's address", "the app". Technical details stay in what you do yourself, or inside the exact thing they paste.
- If a screen doesn't match what you described, ask them to tell you what they see or share a screenshot. Never guess.
- If something fails, say what happened in a sentence or two and the next thing to try. If it still doesn't work, tell them Peak Systems can help and what to tell them.

## Hard rules

- **Never buy anything.** They buy the server themselves through the link below. Never use a purchase tool.
- **Never ask for or handle passwords.** They type their own into Hostinger, Peak Base and Google.
- **Never reinstall or erase a server** without a clear yes, and only on a server that is new or that they confirm is empty.
- **Never delete the `peak-base` project**, and once it runs never create it again under that name. It holds their brain.
- The Google Drive token (step 8) never goes in the chat.

## Start

Give them the plan in five short lines: get a server, put Peak Base on it, install the app on their computer, move their Obsidian notes in, connect Claude. Ask whether they're on Mac or Windows and what's already done (for example, they may have bought the server already) and pick up from there.

Check whether you have Hostinger tools (names like `vps_docker_create`, `vps_virtual-machines_list`). If you do, you can do steps 1 to 3 for them. If not, you guide the clicks. Don't ask them to install anything to get the tools.

## Step 1: the server

They buy the server from Hostinger in their browser, through this link (it carries Peak Systems' referral):

https://www.hostinger.com/cart?product=vps%3Avps_kvm_4&period=12&referral_type=cart_link&REFERRALCODE=YZIBILLYZVMT&referral_id=01a0fd83-b6f5-72ed-b32e-b63823936a7c

Tell them: keep the plan as it is (KVM 4), and if the cart asks what to install, choose **Ubuntu with Docker**. Hostinger may ask them to set a server password; they choose it and keep it to themselves.

With Hostinger tools: `vps_virtual-machines_list` to find the server. If it already exists and something else runs on it, confirm it's the right one and empty before going on. If it has no operating system yet, find an Ubuntu template whose name mentions Docker (`vps_templates_list`) and run `vps_virtual-machines_setup` with it. On a server that already has a different system, `vps_virtual-machines_recreate` erases it: only after a clear yes.

## Step 2: the address

Default: use the address Hostinger already gave the server. No extra setup.
- With tools: read the hostname from `vps_virtual-machines_get` (looks like `srv123456.hstgr.cloud`).
- Without tools: in hPanel, open **VPS**, then their server. The overview shows the hostname. Ask them to read it to you.

Only if they want their own address (like `brain.theircompany.com`):
- Get the server's IP address (from `vps_virtual-machines_get`, or the same overview page).
- Domain on Hostinger and tools connected: show them the record you'll add (type `A`, name `brain`, value the IP, TTL 300), get a yes, then `dns_records_update` with `overwrite: true`.
- Domain elsewhere: tell them exactly what to add where they bought the domain: type `A`, name `brain`, value the IP, TTL 300 (or the lowest offered). Wait until they say it's done.

From here on, `<address>` means the address you settled on, without `https://`.

## Step 3: put Peak Base on the server

**With Hostinger tools:** `vps_docker_create` on their server with:
- `project_name`: `peak-base` (exactly this)
- `content`: `https://raw.githubusercontent.com/BillyRybka/peak-base-releases/main/server/docker-compose.yml`
- `environment`:
  ```
  DOMAIN=<address>
  MCP_SERVER_TITLE=Business Brain
  ```
Then `vps_docker_containers` for `peak-base`: `server`, `postgres`, `caddy`, `backup` and `offsite` running; `init` and `migrate` finished. If something failed, read `vps_docker_logs` before trying again.

**Without tools,** guide the clicks in hPanel:
1. **VPS**, their server, then **Docker Manager**.
2. **Compose from URL**, and paste:
   `https://raw.githubusercontent.com/BillyRybka/peak-base-releases/main/server/docker-compose.yml`
3. Project name: `peak-base`
4. Add two environment settings:
   `DOMAIN` = `<address>`
   `MCP_SERVER_TITLE` = `Business Brain`
5. **Deploy.**

If Docker Manager offers to install Docker first, let it. If it says the operating system must be changed, that erases the server: confirm it's new and empty, and get a clear yes first.

**Check it's live:** open `https://<address>/health`. It should answer ok. The secure connection can take a few minutes to start working on a new address; wait and try again. If it still fails after about ten minutes, check the server's firewall (`vps_firewall_list`, or hPanel **Security > Firewall**): ports 80 and 443 must be open.

## Step 4: the app on their computer

1. Download: https://github.com/BillyRybka/peak-base-releases/releases/latest/download/PeakBase-Mac.dmg
2. Open it and drag **Peak Base** into **Applications**.
3. Open **Terminal** (press Command and Space, type Terminal, press Return), paste this line and press Return:
   `xattr -cr "/Applications/Peak Base.app"`
   Why: a Mac blocks apps from makers it doesn't know yet. This tells it Peak Base is fine. They only do it once; the app updates itself after that.

**On Windows:**
1. Download: https://github.com/BillyRybka/peak-base-releases/releases/latest/download/PeakBase-Windows.exe
2. Open the file. If Windows says it protected the PC, click **More info**, then **Run anyway** (same reason: Windows doesn't know the maker yet). Click through the installer.
3. Peak Base is in the Start menu. It updates itself after this.

## Step 5: the owner account

1. Open Peak Base and enter `https://<address>`.
2. Create their account. The first account owns the server. After that, only people they invite can join.

## Step 6: move their Obsidian vault in

First find where the vault lives (see below). If the folder sits in iCloud Drive (its path has `iCloud` or `Mobile Documents` in it), OneDrive, Dropbox or Google Drive, move it out first: those services can swap files for online-only placeholders, which Peak Base would read as emptied notes. On Windows, OneDrive often holds Documents and Desktop without people knowing: check whether the path has `OneDrive` in it. Have them make a new folder outside those (Mac: `Documents/Business Brain`; Windows: `C:\Users\<their name>\Business Brain`, made in File Explorer under their user folder), copy everything from the vault into it, then in Obsidian **Manage vaults > Open folder as vault** and pick the new folder. From then on they use the new folder; Peak Base is now what keeps it backed up and in sync.

1. In Peak Base choose **Open existing** and pick the folder their Obsidian vault lives in (the one with their notes). Obsidian's own settings folder is skipped on its own.
2. Turn on **sync**. Everything in the folder uploads to their server. A big vault takes a while; let it finish.
3. They can keep using Obsidian on the same folder. Nothing moves.
4. If the folder has a `.claude/skills` folder inside, turn on **Vault settings > General > Sync skills** so their skills reach the brain too.

Don't know where the vault is? In Obsidian, click the vault name at the bottom left, choose **Manage vaults**, then the menu next to their vault and **Reveal in Finder** (Mac) or **Show in system explorer** (Windows). That's the folder to pick. On Windows, clicking the address bar at the top of File Explorer shows the full path.

## Step 7: connect Claude to their brain

1. In Claude: **Settings > Connectors > Add custom connector**.
2. Name: `Business Brain`. Address: `https://<address>/api/mcp`
3. Sign in with their Peak Base account when asked.

ChatGPT works the same way: add a custom connector with the same address and sign in.

Then start a new chat and ask Claude something about their notes to prove it works.

## Later, when they want it

**Backups to their Google Drive.** The server already backs up every night and keeps 14 days. To also keep 30 days in their Google Drive:
1. Install rclone. Windows: open **Terminal** (or PowerShell), run `winget install Rclone.Rclone`, then open a new Terminal window. Mac: `brew install rclone` in Terminal (no Homebrew? Peak Systems can do this step with them).
2. In Terminal: `rclone authorize "drive"`. A browser opens; they sign in to Google and allow access.
3. Terminal prints a block starting with `{"access_token"`. They copy all of it themselves, then in hPanel: **VPS > Docker Manager > peak-base > Environment**, add `GDRIVE_TOKEN` with that block as the value, and redeploy. Tell them not to paste it into this chat.
4. Within a few hours a **Peak Base backups** folder appears in their Drive.

**Inviting their team.** In Peak Base: **Vault settings > Members and access > Invite people**, then **Copy link**. They send the link however they like; it installs the app and connects it to their server. To choose what each person sees, use the access board on the same page: **Can edit**, **Can view** or **No access**.

**Updates.** The app updates itself. For the server: `vps_docker_update` on `peak-base`, or in hPanel open the `peak-base` project in Docker Manager and redeploy.

**Forgotten password or restoring a backup:** Peak Systems handles these.
