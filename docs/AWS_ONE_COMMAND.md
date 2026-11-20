# One-command AWS setup

`infra/rebuild.sh` builds the whole CampusConnect setup on AWS with one command and deletes it with another:

```
./infra/rebuild.sh up      # about 20 minutes, mostly the database being created
./infra/rebuild.sh down    # deletes everything; a final database snapshot is kept
```

It uses AWS CloudFormation (`infra/cloudformation.yaml`) to create the server, the private database and the two security groups together, then connects to the server to finish the job.

## What `up` does

1. Looks up your default network and your current IP address.
2. Creates an SSH key pair if you don't have one (saved to `~/.ssh/campusconnect-key.pem`).
3. Creates one stack: the Ubuntu 26.04 server, the SQL Server Express database (private), and two security groups. SSH is allowed **only from your current IP**; the database accepts connections **only from the server**.
4. The server sets itself up on first boot (Nginx, .NET runtime, the API service) using `backend/deploy/bootstrap-ec2.sh`.
5. Writes `/etc/api.env` on the server with the database address and your secrets.
6. Builds the API on your Mac (or downloads it from GitHub), uploads it and starts it with `deploy.sh`.
7. Loads the demo data: the 7 demo accounts, the 44 realistic complaints and the extra students.
8. Prints the server address and a health check.

The first run asks for three things and remembers them in `~/.campusconnect/secrets.env` (readable only by you): a demo password, your Groq key and your Gemini key. The Groq and Gemini keys can be skipped; the app then works without chat and photo suggestions. The database password and the login-signing key are generated for you.

## Step 1: set up AWS on your Mac (one time)

You need the AWS command-line tool and a set of access keys. Use a dedicated user with limited permissions, never your root account.

**1. Install the tool.** No Homebrew needed:
```
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "$HOME/Downloads/AWSCLIV2.pkg"
sudo installer -pkg "$HOME/Downloads/AWSCLIV2.pkg" -target /
aws --version
```
(With Homebrew you can run `brew install awscli` instead.)

**2. Create a limited user** in the AWS console (signed in as yourself or an admin):
1. Search for **IAM**, then **Policies**, then **Create policy**, then the **JSON** tab. Paste this and save it as `CampusConnectRebuild`:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Sid": "CampusConnectRebuild",
         "Effect": "Allow",
         "Action": ["cloudformation:*", "ec2:*", "rds:*", "ssm:GetParameter", "ssm:GetParameters"],
         "Resource": "*",
         "Condition": { "StringEquals": { "aws:RequestedRegion": "eu-north-1" } }
       }
     ]
   }
   ```
2. **IAM**, then **Users**, then **Create user**. Name it `campusconnect-deployer`. Leave console access off. On the permissions step choose **Attach policies directly** and select `CampusConnectRebuild`.

**3. Create an access key.** Open the new user, then **Security credentials**, then **Create access key**. Choose **Command Line Interface (CLI)**, tick the confirmation, and create it. Copy both values or download the CSV. **The secret is shown only once.**

**4. Give the keys to the tool:**
```
aws configure --profile campusconnect
```
It asks four questions: *Access Key ID*, *Secret Access Key*, *Default region name* (`eu-north-1`) and *Default output format* (`json`). Then tell your terminal to use that profile (add the line to `~/.zshrc` to keep it):
```
export AWS_PROFILE=campusconnect
```

**5. Check it worked:**
```
aws sts get-caller-identity
```
It should print your account number and `user/campusconnect-deployer`.

**Keeping the keys safe**
- Never paste them into a chat, an email, or Git. They sit in `~/.aws/credentials` as plain text, so keep your Mac locked and disk-encrypted.
- When you are not rebuilding, switch the key off: IAM, the user, Security credentials, **Deactivate** (or Delete). Create a new one next time.
- If AWS reports a missing "service-linked role" on a first-ever database, add `iam:CreateServiceLinkedRole` to the policy.
- Turn on MFA for your own AWS login.

## Step 2: build

Check first. This changes nothing and costs nothing:
```
./infra/rebuild.sh check
```
It confirms the tools, your AWS login, the network and that AWS accepts the template. Fix anything marked `[FAIL]`, then:
```
./infra/rebuild.sh up
```

When it finishes, point the app at the new server. The address is printed at the end:
1. GitHub, then the repository, then **Settings, Secrets and variables, Actions, Variables**: set `API_BASE_URL` to `http://<new-ip>/api/v1`.
2. **Actions**, then *Frontend APK*, then **Run workflow**. About 7 minutes later download the APK from **Releases** (`latest`). Uninstall the old app first.

Other commands:
```
./infra/rebuild.sh status    # stack state, addresses, health check
./infra/rebuild.sh ssh       # open a shell on the server
```

## Step 3: delete everything when you are done

```
./infra/rebuild.sh down
```
It asks you to type `DELETE`. It removes the server, the database and the security groups. **A final snapshot of the database is kept** automatically, so nothing is lost. Snapshots cost a little each month; delete one you no longer need with `aws rds delete-db-snapshot --db-snapshot-identifier <name>`.

To bring the same data back later:
```
SNAPSHOT_ID=<snapshot name> ./infra/rebuild.sh up
```
It will ask for the database password the snapshot was created with (it is saved in `~/.campusconnect/secrets.env`) and skips loading demo data.

## Options

| Variable | Effect |
|---|---|
| `AWS_REGION` | Region (default `eu-north-1`) |
| `STACK_NAME` | Stack name (default `campusconnect`) |
| `USE_ELASTIC_IP=true` | A fixed server address that survives restarts; small ongoing charge |
| `AMI_ID=ami-...` | Use this server image instead of the newest Ubuntu 26.04 |
| `SKIP_SEED=1` | Do not load demo data |
| `SNAPSHOT_ID=...` | Restore the database from a snapshot |

## Cost and safety notes

- While the stack exists, the server and the database are billed. Run `down` when you finish a demo.
- Only one stack of this name can exist at a time. Do not run `up` while the old hand-built server and database are still running, or you pay for both.
- The script stores your secrets on your Mac only: `~/.campusconnect/secrets.env` and the key in `~/.ssh/`. Back them up somewhere private; they are not in Git.

## How well this has been tested

- The script's own logic (check, up, status, down, restoring a snapshot, refusing a second run, rejecting an unsafe password) was run end to end against simulated AWS and SSH commands. The CloudFormation file parses and all its references resolve.
- **It has not been run against real AWS yet.** Treat your first `up` as the real test. `check` runs first, free, and catches most problems, including whether AWS accepts the template.
- Two assumptions to watch: that the Ubuntu 26.04 image lookup path is correct (if not, set `AMI_ID`), and that `db.t3.micro` SQL Server Express is available to your account. If `up` fails, run `./infra/rebuild.sh down` to clean up, and send me the error message.

## If something fails

| Symptom | Likely cause |
|---|---|
| `check` says not signed in | Run `aws configure --profile campusconnect` and `export AWS_PROFILE=campusconnect` |
| Stack creation fails on the image | Set `AMI_ID` to an Ubuntu 26.04 image ID for your region |
| Stack creation fails on the database | Read the stack events: `aws cloudformation describe-stack-events --stack-name campusconnect` |
| "Did not accept SSH" | Your IP changed after `up` started, or the key file is missing; rerun after `down` |
| "First-boot setup did not complete" | `./infra/rebuild.sh ssh`, then `sudo cat /var/log/cloud-init-output.log` |
