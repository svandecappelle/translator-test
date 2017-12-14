#!/bin/bash

# check if current dir is git repo
if ! git ls-files >& /dev/null; then
  echo "Fatal: Not a git repository (or any of the parent directories): .git"
  exit 1
fi

# check if access token is set
ACCESS_TOKEN=$(git config auth.token)

usage() {
cat << EOF
usage: ghpr -t <title> [options]

Create a Pull Request (PR) in GitHub.

OPTIONS:
   -h <head>           Branch you want to PR. It has to exist in the remote. (Default: current branch)
   -b <base>           Branch where you want your PR merged into. (Default: master)
   -t <title>          Title of the PR (Default: the last commit's title, as long as there is only one commit in the PR)
   -d <description>    Description of the PR
   -c                  Copy the PR URL to the clipboard
   -f                  Fake run, doesn't make the request but prints the URL and body
   -p                  Private user token to authenticate on Github api
EOF
}
HEAD=$(git symbolic-ref --short HEAD)
BASE=master
giturl=$(git remote -v | awk '/.*github.com.* .push.$/' | head -1)
if [[ $giturl == *"https"* ]]
then 
  OWNER_URL=$(git remote -v | awk '/https:..github.com.* .push.$/ { sub(/^https:\/\/github.com\//, "", $2); print $2 }' | head -1)
else
  OWNER_URL=$(git remote -v | awk '/.*github.com.* .push.$/ { sub(/^.*.com:/, "", $2); print $2 }' | head -1)
fi 
CONTRIBUTOR_URL=$(git remote -v | awk '/git@github.com.* .push.$/ { sub(/^git@github.com:/, "", $2); print $2 }' | head -1)

if [[ -z $OWNER_URL ]]; then
  OWNER_URL=$CONTRIBUTOR_URL
fi
OWNER=$(cut -d/ -f1 <<< $OWNER_URL)
REPO=$(cut -d/ -f2 <<< $OWNER_URL | sed -e 's/\.git$//')
CONTRIBUTOR=$(cut -d/ -f1 <<< $CONTRIBUTOR_URL)

if [[ $# -eq 0 ]]; then
  usage
  exit
fi

while getopts “h:b:t:d:p:cf” OPTION
do
  case $OPTION in
    h)
      HEAD=$OPTARG;;
    b)
      BASE=$OPTARG;;
    t)
      TITLE=$OPTARG;;
    d)
      DESCRIPTION=$OPTARG;;
    c)
      CLIPBOARD=true;;
    f)
      FAKE=true;;
    p)
      ACCESS_TOKEN=$OPTARG;;
    ?)
      usage
      exit;;
  esac
done

if [[ -z $ACCESS_TOKEN ]]; then
  echo "Oops! Seems to be a problem with your Github API token. Use below link to generate token"
  echo "  https://github.com/settings/tokens/new"
  echo "and then run this command to save token"
  echo "  git config --global auth.token YOUR_ACCESS_TOKEN"
  exit 1
else
  if [[ $(git remote -v) == *"$ACCESS_TOKEN"* ]]
  then
    echo "Using access token" 
    OWNER_URL=$(git remote -v | cut -d'/' -f4-5 | cut -d' ' -f1 | head -1)
    CONTRIBUTOR_URL=$(git remote -v | awk '/git@github.com.* .push.$/ { sub(/^git@github.com:/, "", $2); print $2 }' | head -1)

    if [[ -z $OWNER_URL ]]; then
        OWNER_URL=$CONTRIBUTOR_URL
    fi
    OWNER=$(cut -d/ -f1 <<< $OWNER_URL)
    REPO=$(cut -d/ -f2 <<< $OWNER_URL | sed -e 's/\.git$//')
    CONTRIBUTOR=$(cut -d/ -f1 <<< $CONTRIBUTOR_URL)
  fi
fi

if [[ -z $TITLE ]]; then
  COUNT=$(git log --oneline $BASE..HEAD | wc -l)
  if [[ $COUNT -eq 1 ]]; then
    TITLE=$(git log -1 --pretty=%s)
  else
    cat <<-EOS >&2
Refusing to choose a PR title for you, since there are many commits to choose from. Please specify -t yourself.
EOS
    exit 1
  fi
fi

if [[ $OWNER != $CONTRIBUTOR ]]; then
  HEAD=$CONTRIBUTOR:$HEAD
fi

BODY=("\"head\": \"$HEAD\"", "\"base\": \"$BASE\"", "\"title\": \"$TITLE\"")

if [[ -n $DESCRIPTION ]]; then
  BODY+=(", \"body\": \"$(sed -e 's/$/\\n/' <<< "$DESCRIPTION" | tr -d '\n')\"")
fi

BODY="{${BODY[*]}}"

PR_URL="https://api.github.com/repos/$OWNER/$REPO/pulls"

if [[ $FAKE ]]; then
  echo "Fake run, not making the request"
  echo "  $PR_URL"
  echo "  $BODY"
  exit
else
  echo "curl -s -H "Authorization: token $ACCESS_TOKEN" -H "Content-Type: application/json" -d "$BODY" $PR_URL"
  RESPONSE=$(curl -s -H "Authorization: token $ACCESS_TOKEN" -H "Content-Type: application/json" -d "$BODY" $PR_URL)
fi

URL=$(echo $RESPONSE | grep -Eo "\"html_url\": \"(.*?\/pull\/\\d+)\"," | sed -E "s/.*\"(https.*)\",/\\1/")
if [[ -n $URL ]]; then
  echo $URL
else
  echo $RESPONSE
fi

if [[ $CLIPBOARD ]]; then
  if [[ $(type pbcopy) == *"not found"* ]]; then
    CLIP_COMMAND="xclip -selection clipboard"
  else
    CLIP_COMMAND="pbcopy"
  fi

  echo $URL | $CLIP_COMMAND
fi
