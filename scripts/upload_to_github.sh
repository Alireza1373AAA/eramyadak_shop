#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/upload_to_github.sh <repository-name> [options]

Options:
  --org <organization>    Create the repository inside the given GitHub organization.
  --remote <name>         Git remote name to configure (default: origin).
  --branch <name>         Local branch to push (default: current checked-out branch).
  --visibility <value>    Repository visibility: public or private (default: private).
  --description <text>    Optional description to set on the GitHub repository.
  --token <value>         GitHub token to use for authentication.
  --token-file <path>     Read the GitHub token from the given file.
  --login <username>      GitHub username to associate with the push (defaults to detected owner).
  --auto-commit           Stage and commit any pending changes before pushing.
  --commit-message <msg>  Commit message to use with --auto-commit (default provided).
  -h, --help              Show this help message.

Environment variables:
  GITHUB_TOKEN            Personal access token with repo scope.
  GITHUB_LOGIN            GitHub username used for pushes if --login is omitted.

The script creates the remote repository (if it does not exist yet),
configures the git remote, and pushes the selected branch.
USAGE
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: '$1' command is required." >&2
    exit 1
  fi
}

require_cmd git
require_cmd curl
require_cmd python3

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

remote_name="origin"
branch="$(git rev-parse --abbrev-ref HEAD)"
visibility="private"
description=""
org=""
repo_name=""
token="${GITHUB_TOKEN:-}"
login="${GITHUB_LOGIN:-}"
auto_commit=false
commit_message="chore: upload project"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --remote)
      [[ $# -lt 2 ]] && { echo "Error: --remote requires a value." >&2; exit 1; }
      remote_name="$2"
      shift 2
      ;;
    --branch)
      [[ $# -lt 2 ]] && { echo "Error: --branch requires a value." >&2; exit 1; }
      branch="$2"
      shift 2
      ;;
    --visibility)
      [[ $# -lt 2 ]] && { echo "Error: --visibility requires a value." >&2; exit 1; }
      visibility="$2"
      shift 2
      ;;
    --description)
      [[ $# -lt 2 ]] && { echo "Error: --description requires a value." >&2; exit 1; }
      description="$2"
      shift 2
      ;;
    --org)
      [[ $# -lt 2 ]] && { echo "Error: --org requires a value." >&2; exit 1; }
      org="$2"
      shift 2
      ;;
    --token)
      [[ $# -lt 2 ]] && { echo "Error: --token requires a value." >&2; exit 1; }
      token="$2"
      shift 2
      ;;
    --token-file)
      [[ $# -lt 2 ]] && { echo "Error: --token-file requires a path." >&2; exit 1; }
      token="$(<"$2")"
      shift 2
      ;;
    --login)
      [[ $# -lt 2 ]] && { echo "Error: --login requires a value." >&2; exit 1; }
      login="$2"
      shift 2
      ;;
    --auto-commit)
      auto_commit=true
      shift
      ;;
    --commit-message)
      [[ $# -lt 2 ]] && { echo "Error: --commit-message requires a value." >&2; exit 1; }
      commit_message="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ -z "$repo_name" ]]; then
        repo_name="$1"
        shift
      else
        echo "Error: unexpected argument '$1'." >&2
        usage
        exit 1
      fi
      ;;
  esac
done

if [[ -z "$repo_name" ]]; then
  echo "Error: repository name is required." >&2
  usage
  exit 1
fi

if [[ "$auto_commit" == true && -z "$commit_message" ]]; then
  echo "Error: --commit-message cannot be empty when --auto-commit is enabled." >&2
  exit 1
fi

case "$visibility" in
  public|private) ;;
  *)
    echo "Error: visibility must be 'public' or 'private'." >&2
    exit 1
    ;;
esac

if [[ -z "$token" ]]; then
  read -rsp "GitHub token (input hidden): " token
  echo
fi

if [[ -z "$token" ]]; then
  echo "Error: GitHub token not provided. Supply it via --token, --token-file, GITHUB_TOKEN, or interactive prompt." >&2
  exit 1
fi

api_base="https://api.github.com"
auth_header="Authorization: token ${token}"
accept_header="Accept: application/vnd.github+json"

if [[ -n "$org" ]]; then
  owner="$org"
  create_url="${api_base}/orgs/${org}/repos"
else
  echo "Fetching GitHub account information..."
  user_json="$(curl -sSf -H "$auth_header" -H "$accept_header" "${api_base}/user")"
  owner="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["login"])' <<<"${user_json}")"
  create_url="${api_base}/user/repos"
fi

if [[ -z "$login" ]]; then
  login="$owner"
fi

repo_exists=false
status_code=$(curl -sS -o /dev/null -w "%{http_code}" -H "$auth_header" -H "$accept_header" "${api_base}/repos/${owner}/${repo_name}")
if [[ "$status_code" == "200" ]]; then
  repo_exists=true
elif [[ "$status_code" != "404" ]]; then
  echo "Error: unable to check repository status (HTTP ${status_code})." >&2
  exit 1
fi

if [[ "$repo_exists" == false ]]; then
  echo "Creating repository '${owner}/${repo_name}'..."
  visibility_flag=$( [[ "$visibility" == "private" ]] && echo true || echo false )
  payload=$(python3 - "$repo_name" "$visibility_flag" "$description" <<'PY'
import json
import sys

name = sys.argv[1]
is_private = sys.argv[2] == "true"
description = sys.argv[3]

payload = {"name": name, "private": is_private}
if description.strip():
    payload["description"] = description

print(json.dumps(payload))
PY
)
  response_file=$(mktemp)
  status_code=$(curl -sS -o "$response_file" -w "%{http_code}" -X POST -H "$auth_header" -H "$accept_header" -d "$payload" "$create_url")
  if [[ "$status_code" -lt 200 || "$status_code" -ge 300 ]]; then
    echo "Error: failed to create repository (HTTP ${status_code})." >&2
    cat "$response_file" >&2
    rm -f "$response_file"
    exit 1
  fi
  rm -f "$response_file"
else
  echo "Repository '${owner}/${repo_name}' already exists. Skipping creation."
fi

remote_url="https://github.com/${owner}/${repo_name}.git"
if git remote | grep -Fxq "$remote_name"; then
  echo "Updating remote '${remote_name}' to ${remote_url}"
  git remote set-url "$remote_name" "$remote_url"
else
  echo "Adding remote '${remote_name}' pointing to ${remote_url}"
  git remote add "$remote_name" "$remote_url"
fi

if [[ "$auto_commit" == true ]]; then
  if git rev-parse --verify HEAD >/dev/null 2>&1; then
    if git diff --quiet --ignore-submodules HEAD --; then
      echo "Auto-commit enabled but no changes detected; skipping commit."
    else
      echo "Auto-commit: staging and committing pending changes..."
      git add -A
      git commit -m "$commit_message"
    fi
  else
    if git status --porcelain --untracked-files=all | grep -q .; then
      echo "Auto-commit: creating initial commit..."
      git add -A
      git commit -m "$commit_message"
    else
      echo "Auto-commit enabled but working tree is clean; skipping commit."
    fi
  fi
fi

if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
  echo "Error: current branch has no commits to push. Create a commit manually or rerun with --auto-commit." >&2
  exit 1
fi

echo "Preparing to push branch '${branch}'..."
tmp_askpass=$(mktemp)
cat <<'ASKPASS' > "$tmp_askpass"
#!/usr/bin/env bash
case "$1" in
*Username*)
  echo "$GITHUB_LOGIN"
  ;;
*Password*)
  echo "$GITHUB_TOKEN"
  ;;
esac
ASKPASS
chmod +x "$tmp_askpass"

GIT_ASKPASS="$tmp_askpass" GITHUB_LOGIN="$login" GITHUB_TOKEN="$token" GIT_TERMINAL_PROMPT=0 git push -u "$remote_name" "$branch"
rm -f "$tmp_askpass"

echo "Repository uploaded successfully to https://github.com/${owner}/${repo_name}"
