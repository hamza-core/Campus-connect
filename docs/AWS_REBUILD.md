# Rebuilding CampusConnect on AWS from scratch

> **Shortcut:** `./infra/rebuild.sh up` does all of this in one command (and `down` deletes it). See [AWS_ONE_COMMAND.md](AWS_ONE_COMMAND.md), which also explains how to set up AWS credentials on your Mac. This page is the manual version and the reference for what the script builds.

Use this when the AWS services have been deleted (to save credits) and you want to show the app again. A rebuild takes roughly 40 minutes, most of it waiting for the database to be created. Nothing here is secret; the secret values are listed by name only (see step 0).

## 0. Before deleting anything: save these

| Save this | Where it is now | If you lose it |
|---|---|---|
| **Secrets file `/etc/api.env`** (database password, `JWT_SECRET`, Groq key, Gemini key) | On the EC2 server | Make new ones: a new JWT secret just logs everyone out; new free Groq and Google AI Studio keys take two minutes |
| **SSH key `Sg-campusConnect.pem`** | `~/Desktop` on your Mac | Create a new key pair when you launch the new server |
| **The demo password (`SEED_PASSWORD`)** | Your notes | Choose a new one when you re-seed |
| **A database snapshot** (optional) | AWS console | Skip it: the demo data can be regenerated (step 5, option B) |

To copy the secrets file to your Mac, run this yourself and keep the result in a password manager, never in Git or a chat:

```
ssh -i ~/Desktop/Sg-campusConnect.pem ubuntu@<server-ip> 'sudo cat /etc/api.env' > ~/api.env.backup && chmod 600 ~/api.env.backup
```

**Keeping the database exactly as it is:** when you delete the RDS instance, tick *Create final snapshot*. Restoring that snapshot later brings back every user and complaint. A snapshot costs a small storage fee. If you skip it you lose only the registered test accounts, because the demo data is rebuilt by a command.

## 1. What the current setup looks like

| Item | Value |
|---|---|
| Region | `eu-north-1` (Stockholm), default VPC |
| Server | EC2 `api-server`, `t3.micro`, Ubuntu 26.04 LTS (x86_64), about 20 GiB disk |
| Server security group (`launch-wizard-1`) | Inbound 22 (SSH), 80 (HTTP), 443 (unused) |
| Database | RDS **SQL Server Express**, instance `campusconnectv1`, database `CampusConnect`, master user `admin`, **not publicly accessible** |
| Database security group (`db-sg`) | Inbound 1433 from the server's security group only |
| Web server | Nginx on port 80, forwards to the API on `127.0.0.1:5000` |
| API | ASP.NET Core 10, systemd service `api`, files in `/home/ubuntu/api`, settings in `/etc/api.env` |
| Photos | `/home/ubuntu/uploads` on the server disk |

Not readable from the server, so check them in the RDS console (RDS, then `campusconnectv1`, Configuration) and write them down: **instance class, storage size and type, engine version.** A `db.t3.micro` with 20 GiB is the usual free-tier choice.

## 2. What keeps costing money while "turned off"

- **RDS:** a stopped instance restarts by itself after 7 days, and its storage is billed. Delete it (with a final snapshot if you want the data).
- **EC2:** a stopped instance still bills for its disk. Terminate it to stop all charges.
- **Public and Elastic IP addresses:** they carry a small hourly fee. Release any you are not using.
- **Snapshots:** a small monthly storage fee each.
- **Other leftovers:** the earlier notes mention an unused **Aurora cluster `database-1`**. Check the RDS console to be sure it is gone.
- Set an **AWS Budget alert** so a surprise charge is caught early.

## 3. Rebuild, step by step

1. **Server security group.** EC2 then Security Groups, create one allowing inbound 22 (your IP only), 80 (anywhere) and, if you plan HTTPS later, 443.
2. **Launch the server.** EC2 then Launch instance: *Ubuntu Server 26.04 LTS*, `t3.micro`, 20 GiB disk, your key pair, the security group from step 1. Note its **public IP address**. (Optional: allocate and attach an Elastic IP so the address survives a restart.)
3. **Database security group.** Create `db-sg` allowing inbound **1433** with the source set to the server's security group.
4. **Create the database.** RDS then Create database: *SQL Server*, *Express edition*, `db.t3.micro` (or the class you wrote down), 20 GiB, master user `admin` with a password you save, **Public access: No**, security group `db-sg`. This takes 10 to 20 minutes. Copy its **endpoint** when ready.
   *To keep the old data instead:* RDS then Snapshots, select the final snapshot, Actions, **Restore snapshot**, with the same settings.
5. **Prepare the server.** Copy the bootstrap script up and run it:
   ```
   scp -i <key>.pem backend/deploy/bootstrap-ec2.sh ubuntu@<server-ip>:~/
   ssh -i <key>.pem ubuntu@<server-ip> 'bash bootstrap-ec2.sh'
   ```
   It installs the .NET runtime and Nginx, writes the Nginx and systemd configuration, and creates a settings template at `/etc/api.env`. It is safe to run on a server that is already working: `bash bootstrap-ec2.sh --check` only reports what it would change, it never upgrades installed packages or restarts the API, and it only rewrites a file that differs (after saving a `.bak` copy). Run against the current live server it reports "nothing to change". Then edit the settings: `ssh ... 'sudo nano /etc/api.env'` and replace every `<placeholder>` (database endpoint and password, a new JWT secret from `openssl rand -base64 48`, and the two AI keys).
6. **Put the API on the server.**
   - Build it: `cd backend && dotnet publish src/CampusConnect.Api -c Release -r linux-x64 --self-contained false -o publish` (afterwards run `git checkout -- src/CampusConnect.Api/packages.lock.json tests/CampusConnect.Tests/packages.lock.json`). Alternatively download the `backend-api` artifact from the latest *Backend CI* run on GitHub.
   - Upload and start it:
     ```
     ssh -i <key>.pem ubuntu@<server-ip> 'rm -rf ~/api-new && mkdir ~/api-new'
     scp -i <key>.pem -r publish/. ubuntu@<server-ip>:~/api-new/
     ssh -i <key>.pem ubuntu@<server-ip> 'bash -s' < backend/deploy/deploy.sh
     ```
     The script applies database migrations, starts the API and checks that it is healthy.
7. **Load the data** (skip this if you restored a snapshot). On a brand-new database run these two commands on the server, in this order. Pick a demo password for `SEED_PASSWORD`:
   ```
   # 1) creates the departments and the 7 demo accounts
   sudo systemd-run --wait --pipe -q -p EnvironmentFile=/etc/api.env -p WorkingDirectory=/home/ubuntu/api -p User=ubuntu \
     --setenv=SEED_PASSWORD='<password>' /usr/bin/dotnet /home/ubuntu/api/CampusConnect.Api.dll --seed
   # 2) replaces the plain sample data with the 44 realistic complaints and adds the extra student accounts
   sudo systemd-run --wait --pipe -q -p EnvironmentFile=/etc/api.env -p WorkingDirectory=/home/ubuntu/api -p User=ubuntu \
     --setenv=SEED_PASSWORD='<password>' --setenv=CONFIRM_RESET=delete-all-complaints \
     /usr/bin/dotnet /home/ubuntu/api/CampusConnect.Api.dll --reset-demo
   ```
   Run `--seed` first: `--reset-demo` renames and extends existing accounts but does not create the admin accounts by itself.
8. **Check it works.** `curl http://<server-ip>/api/v1/health` should return `{"status":"ok"}`. Then sign in to the app with `student@campusconnect.edu`, `labit@campusconnect.edu` and `super@campusconnect.edu`.

## 4. What to change in the app

**Nothing in the code.** The server address is only baked in when the APK is built. A new server almost always has a new IP address, so build a new APK that points at it:

- **With GitHub (easiest):** open the repository, then Settings, Secrets and variables, Actions, **Variables**, and add `API_BASE_URL` = `http://<new-ip>/api/v1`. Then go to Actions, *Frontend APK*, **Run workflow**. About 7 minutes later the new APK is in the **Releases** page under `latest`.
- **On your Mac:** `cd frontend && flutter build apk --release --dart-define=API_BASE_URL=http://<new-ip>/api/v1`, then copy `build/app/outputs/flutter-apk/app-release.apk` wherever you like.

Install the new APK on the phone (uninstall the old one first, because the signing key differs).

Also update, if you use them: the GitHub secret `EC2_HOST` (for automatic deploys), and the old IP in the README and docs.

**To avoid rebuilding the APK every time:** keep an Elastic IP (it costs a little each month), or point a domain name at the server once. With a domain you rebuild the APK a single time, and afterwards only change the DNS record when the server changes.

## 5. If something does not work

- **App says it cannot connect:** the APK points at the old IP, or port 80 is not open in the server's security group.
- **`/health` fails:** `ssh` in and run `journalctl -u api -n 50 --no-pager`. A wrong database endpoint or password in `/etc/api.env` is the usual cause.
- **Database connection times out:** `db-sg` must allow 1433 from the **server's security group**, and the database must be in the same VPC.
- **Chat or photo suggestions do nothing:** check the Groq and Gemini keys in `/etc/api.env`. The free tiers have daily limits.
