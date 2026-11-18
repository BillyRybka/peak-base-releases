# Join your team's Peak Base

Someone on your team invited you to their business brain. This takes about ten minutes. You need the invite link they sent you.

## 1. Install the app

Open your invite link. The page has a download button for your computer.

- **Windows:** run the file you downloaded. If Windows says it protected your PC, click **More info**, then **Run anyway**.
- **Mac:** open the file you downloaded and drag **Peak Base** into **Applications**. Open Peak Base from Applications. If your Mac says it can't be opened, open **System Settings > Privacy & Security**, scroll down, click **Open Anyway** next to Peak Base, and confirm.

The app updates itself from then on.

## 2. Join

Go back to the invite page and click **Open Peak Base**. If Peak Base asks whether to use this server, say yes.

## 3. Make your account

Click **Create account**. Use the exact email your invitation was sent to; the invite page shows it.

For the password: make it in your password manager first (or write it down on paper), then paste or type it in. Your password manager can't save it from inside the app. Click the eye in the password box to check what you typed.

You land in your team's notes, and they download to your computer. A big vault takes a few minutes.

## 4. Connect Claude

This lets Claude read and write your team's notes from any chat, on your computer or your phone. Claude sees only what you can see.

1. In the Claude app, open **Settings > Connectors** and click **Add custom connector**.
2. Name it **Business Brain**.
3. For the address, take your invite link, keep everything before `/invite/`, and add `/api/mcp` to the end. If your invite link is `https://srv123456.hstgr.cloud/invite/abc`, the address is:

   ```
   https://srv123456.hstgr.cloud/api/mcp
   ```

4. Click **Add**, then **Connect**. Sign in with your Peak Base email and password, then click **Allow**.
5. Open a new chat and ask Claude something your team's notes would know. The first time it uses a Business Brain tool, Claude may ask; **Always allow** is fine.

## If something goes wrong

- **The invite page says the invitation expired, was used, or was withdrawn:** ask the person who invited you for a new link. If you already used it, just sign in.
- **You can't see a folder you need:** ask the person who invited you to give you access.
- **You forgot your password:** use **Forgot password?** on the sign-in screen if it's there. If not, ask the person who invited you.
