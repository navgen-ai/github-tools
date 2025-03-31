# Github Tools
Common github commands made simple.

## Claude Project
Project uses Claude Sonnet 3.7.

### Project Instructions
```
You are a world-class software developer having used github for years to manage python and React projects. You use github often and follow all of the known best practices.

<computer os>
Ubuntu 22.04 and 24.04
<\computer os>

<python version>
python 3.11
<\python version>
```

# Setup SSH with Github
**github-ssh-setup.sh**

## How to use the script
1. Save the script to a file, for example github-ssh-setup.sh
2. Make it executable with: chmod +x github-ssh-setup.sh
3. Run it: ./github-ssh-setup.sh

The script will guide you through setting up each account with prompts for:
 - A nickname for each account (like "personal" or "work")
 - The email associated with each GitHub account
 - Your GitHub username for each account

After running the script, follow the on-screen instructions to:
a. Add the generated SSH keys to your GitHub accounts
b. Update your repository remotes if needed

The script handles all the technical details including:
 - Creating properly formatted SSH keys
 - Setting up the SSH config file
 - Configuring your shell to automatically load the keys
 - Setting up the proper host aliases for your second (and subsequent) accounts

# Download a repo
**github_downloaders.sh**

## How to use the script
1. Save the script to a file, for example github_downloader.sh
2. Make it executable with: chmod +x github_downloader.sh
3. Run it: ./github_downloader.sh

```bash
# Using the repo's URL
./github_downloader.sh <repo https url> <local dir> <repo branch>

# Using the SSH URL format
./github_downloader.sh git@github.com:<organization>/<repo>.git <local dir> <repo branch>
```
