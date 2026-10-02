# Peak Base: client setup

One sitting with the client. You need their Hostinger login, a domain or subdomain for their brain, their Google account (for backups), and their computer.

## 1. The server

1. Hostinger: buy the **KVM 4** VPS through Peak Systems' link (it carries the referral and a free domain for a year), operating system **Ubuntu with Docker**. Note its IP address.
   https://www.hostinger.com/cart?product=vps%3Avps_kvm_4&period=12&referral_type=cart_link&REFERRALCODE=YZIBILLYZVMT&referral_id=01a0fd83-b6f5-72ed-b32e-b63823936a7c
2. DNS: add an **A record** for the brain's address (for example `brain.clientco.com`) pointing at that IP. Do this first; HTTPS needs it.
3. Hostinger: VPS > Docker Manager > **Compose from URL**:
   `https://raw.githubusercontent.com/BillyRybka/peak-base-releases/main/server/docker-compose.yml`
4. Environment variables:
   - `DOMAIN` = the brain's address, without `https://` (required)
   - `GDRIVE_TOKEN` = see step 3 below (add it now or later)
   - `MCP_SERVER_TITLE` = what AI apps call the connector (default "Business Brain")
5. Deploy. In a minute or two, `https://<DOMAIN>/health` answers `ok`.

## 2. The owner account

1. Install Peak Base on the client's computer:
   - Windows: `https://github.com/BillyRybka/peak-base-releases/releases/latest/download/PeakBase-Windows.exe`. If Windows says it protected the PC: **More info**, then **Run anyway**.
   - Mac: `https://github.com/BillyRybka/peak-base-releases/releases/latest/download/PeakBase-Mac.dmg`. Drag Peak Base into Applications, then open Terminal and run once:
     `xattr -cr "/Applications/Peak Base.app"`
2. Open Peak Base, enter the brain's address, and create the owner account. The first account owns the server; after that, only invited people can join.
3. Create the vault, or open the folder they already keep notes in, and turn on sync.

## 3. Backups to their Google Drive

The server backs up every night on its own and keeps 14 days. To also keep 30 days in the client's Google Drive:

1. On any computer: install rclone (Windows: `winget install Rclone.Rclone`; Mac: `brew install rclone`).
2. Run `rclone authorize "drive"`. A browser opens; the client signs in to Google and allows access.
3. The terminal prints a block starting with `{"access_token"`. Copy all of it into `GDRIVE_TOKEN` in Docker Manager and redeploy.
4. Within a few hours a folder **Peak Base backups** appears in their Drive.

## 4. Teammates

In Peak Base: vault settings > Members > invite by email > **Copy link**. Send that link however you like. It opens a page that downloads the right installer and then opens Peak Base with the server already filled in.

## 5. AI apps

Connector address: `https://<DOMAIN>/api/mcp`. Claude (chat, Cowork, Code), ChatGPT and Codex sign in through it.

## When something goes wrong

Container names below assume the project is called `peak-base`. If Docker Manager named it something else, use that name in place of `peak-base`, and run the restore as `PROJECT=<name> sh restore.sh`.

- **Forgotten password:** in Hostinger's browser terminal, `docker exec -it peak-base-server-1 node dist/scripts/set-password.js person@clientco.com`
- **Restore a backup:** download `restore.sh` from the same `server` folder, then `sh restore.sh` lists the backups and `sh restore.sh <name>` puts one back. `sh restore.sh --drive` works from Google Drive.
- **Update the server:** Docker Manager > the project > redeploy (it pulls the newest image).
