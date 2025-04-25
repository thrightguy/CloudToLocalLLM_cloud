# Deploying CloudToLocalLLM Cloud Portal on Render.com

This guide walks you through deploying your CloudToLocalLLM cloud portal (Flutter web) to Render.com. No coding or technical expertise required!

---

## 1. Prerequisites
- You have a GitHub account.
- Your cloud portal code is already in a GitHub repository (this repo).
- You have a free or paid Render.com account.

---

## 2. Steps to Deploy

1. **Log in to [Render.com](https://render.com/)**
2. Click **"New +"** and select **"Web Service"**.
3. Connect your GitHub account and select your cloud portal repo.
4. Render will detect the `Dockerfile` automatically. If prompted:
   - **Build Command:** Leave blank (Dockerfile handles build)
   - **Start Command:** Leave blank (Dockerfile handles start)
5. Choose a region and plan (free is fine for most uses).
6. Click **"Create Web Service"**.
7. Wait for the build and deploy process to finish (a few minutes).
8. When complete, your portal will be available at the provided Render URL.

---

## 3. Updating the Portal
- Make changes in your repo and push to GitHub.
- Render will automatically rebuild and redeploy your portal.

---

## 4. Troubleshooting
- If the site doesn't load, check the Render build logs for errors.
- Make sure only the required files are in your repo: `lib/`, `web/`, `pubspec.yaml`, `Dockerfile`, and the READMEs.
- For help, see [Render Docs](https://render.com/docs/deploy-docker).

---

**That's it! You now have a cloud-hosted portal for CloudToLocalLLM, accessible from anywhere.**
