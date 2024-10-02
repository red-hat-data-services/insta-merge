#!/usr/bin/env bash

set -x

UPSTREAM_REPO=$1
UPSTREAM_BRANCH=$2
DOWNSTREAM_BRANCH=$3
GITHUB_TOKEN=$4
FETCH_ARGS=$5
MERGE_ARGS=$6
PUSH_ARGS=$7
SPAWN_LOGS=$8
DOWNSTREAM_REPO=$9
IGNORE_FILES=${10}
PR_URL=${11}

export GH_TOKEN=${GITHUB_TOKEN}
PR_MERGE_RESULT=$(gh pr merge --merge --admin ${PR_URL})
if [[ $PR_MERGE_RESULT == *"Merged pull request"* ]]
then
  echo "Merged the PR!!"
  exit 0
fi

if [[ -z "$UPSTREAM_REPO" ]]; then
  echo "Missing \$UPSTREAM_REPO"
  exit 1
fi


if [[ -z "$UPSTREAM_BRANCH" ]]
then
  REPO_NAME=${UPSTREAM_REPO/https:\/\/github.com\//}
  REPO_NAME=${REPO_NAME%.git}
  echo "REPO_NAME=$REPO_NAME"
  UPSTREAM_BRANCH=$(curl -s https://api.github.com/repos/$REPO_NAME | jq -r '.default_branch')
  echo "UPSTREAM_BRANCH=$UPSTREAM_BRANCH"
fi

if [[ -z "$DOWNSTREAM_BRANCH" ]]; then
  echo "Missing \$DOWNSTREAM_BRANCH"
  echo "Default to ${UPSTREAM_BRANCH}"
  DOWNSTREAM_BREANCH=UPSTREAM_BRANCH
fi

if ! echo "$UPSTREAM_REPO" | grep '\.git'; then
  UPSTREAM_REPO="https://github.com/${UPSTREAM_REPO_PATH}.git"
fi

echo "UPSTREAM_REPO=$UPSTREAM_REPO"

if [[ $DOWNSTREAM_REPO == "GITHUB_REPOSITORY" ]]
then
  git clone "https://github.com/${GITHUB_REPOSITORY}.git" work
  cd work || { echo "Missing work dir" && exit 2 ; }
  git remote set-url origin "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
else
  git clone $DOWNSTREAM_REPO work
  cd work || { echo "Missing work dir" && exit 2 ; }
  git remote set-url origin "https://x-access-token:${GITHUB_TOKEN}@github.com/${DOWNSTREAM_REPO/https:\/\/github.com\//}"
fi



git config user.name "${GITHUB_ACTOR}"
git config user.email "${GITHUB_ACTOR}@users.noreply.github.com"
git config --local user.password ${GITHUB_TOKEN}
git config --global merge.ours.driver true

git remote add upstream "$UPSTREAM_REPO"
git fetch ${FETCH_ARGS} upstream
git remote -v

git checkout origin/${DOWNSTREAM_BRANCH}
git checkout -b ${DOWNSTREAM_BRANCH}

case ${SPAWN_LOGS} in
  (true)    echo -n "sync-upstream-repo https://github.com/dabreadman/sync-upstream-repo keeping CI alive."\
            "UNIX Time: " >> sync-upstream-repo
            date +"%s" >> sync-upstream-repo
            git add sync-upstream-repo
            git commit sync-upstream-repo -m "Syncing upstream";;
  (false)   echo "Not spawning time logs"
esac

git push origin ${DOWNSTREAM_BRANCH}

IFS=', ' read -r -a exclusions <<< "$IGNORE_FILES"
for exclusion in "${exclusions[@]}"
do
   echo "$exclusion"
   echo "$exclusion merge=ours" >> .gitattributes
   cat .gitattributes
done

MERGE_RESULT=$(git merge ${MERGE_ARGS} upstream/${UPSTREAM_BRANCH})

rm -rf .gitattributes

if [[ $MERGE_RESULT == "" ]] || [[ $MERGE_RESULT == *"merge failed"* ]]
then
  exit 1
elif [[ $MERGE_RESULT != *"Already up to date."* ]]
then
  git commit -m "Merged upstream"
  git push ${PUSH_ARGS} origin ${DOWNSTREAM_BRANCH} || exit $?
  sleep 2
fi

cd ..
rm -rf work
