#!/bin/sh
set -eu
root=$(CDPATH= cd "$(dirname "$0")/../.." && pwd)
check=$root/tools/workflow/check-ref
count=0
ok() { "$check" "$1" "$2" || { printf 'Unexpected rejection: %s %s\n' "$1" "$2" >&2; exit 1; }; count=$((count+1)); }
no() { if "$check" "$1" "$2"; then printf 'Unexpected acceptance: %s %s\n' "$1" "$2" >&2; exit 1; fi; count=$((count+1)); }
for type in feature fix docs refactor perf test build ci chore revert; do ok topic "$type/sg-35-add-examples"; done
ok branch main
ok ref refs/heads/fix/sg-1-repair-a1
ok ref refs/tags/v1.2.3
ok tag v0.1.0-rc.1
for name in main develop feature/no-issue feature/sg-0-test feature/sg-01-test feature/SG-1-test feature/sg-1-Test feature/sg-1-a--b feature/sg-1-a- feature/sg-1--a feature/sg-1-a/b agent/feature/sg-1-a feature/sg-1-a_b feature/sg-1-é 'feature/sg-1-$(false)' 'feature/sg-1-a b' '' '1/merge' 'gh-readonly-queue/main/pr-1'; do no topic "$name"; done
no topic 'feature/sg-1-a
feature/sg-2-b'
no topic "$(printf 'fix/sg-1-a\r')"
no branch release/1.2.x
no branch develop
no tag v01.2.3
no tag 1.2.3
no ref refs/notes/review
no ref refs/heads/bad
# Scratch repositories isolate refspec tests and never contact a remote service.
scratch=${TMPDIR:-/tmp}/workflow-tests.$$
(umask 077; mkdir "$scratch")
trap 'rm -rf "$scratch"' 0 HUP INT TERM
git init -q "$scratch/repo"
git init -q --bare "$scratch/remote"
mkdir -p "$scratch/repo/tools/workflow" "$scratch/repo/.workflow" "$scratch/repo/.githooks"
cp "$root/tools/workflow/check-ref" "$root/tools/workflow/new-branch" "$scratch/repo/tools/workflow/"
cp "$root/.workflow/grammar.sh" "$scratch/repo/.workflow/"
cp "$root/.githooks/pre-push" "$scratch/repo/.githooks/"
(
 cd "$scratch/repo"
 git config user.name 'Test Author'
 git config user.email 'test@example.invalid'
 git config core.hooksPath .githooks
 git add .
 git commit -qm seed
 ./tools/workflow/new-branch docs sg-35-test-helper >/dev/null
 [ "$(git symbolic-ref --short HEAD)" = docs/sg-35-test-helper ]
 if ./tools/workflow/new-branch agent sg-35-bad >/dev/null 2>&1; then exit 1; fi
 # Invoking this helper from another checkout must not mutate either checkout.
 git init -q "$scratch/other"
 (
  cd "$scratch/other"
  if "$scratch/repo/tools/workflow/new-branch" docs sg-35-wrong-repo >/dev/null 2>&1; then exit 1; fi
 )
 (
  cd "$scratch"
  if "$scratch/repo/tools/workflow/new-branch" docs sg-35-outside-repo >/dev/null 2>&1; then exit 1; fi
 )
 [ "$(git symbolic-ref --short HEAD)" = docs/sg-35-test-helper ]
 [ -z "$(git for-each-ref refs/heads/docs/sg-35-wrong-repo)" ]
 mkdir subdir
 (
  cd subdir
  ../tools/workflow/new-branch fix sg-35-same-worktree >/dev/null
 )
 [ "$(git symbolic-ref --short HEAD)" = fix/sg-35-same-worktree ]
 git remote add local "$scratch/remote"
 git push -q local HEAD:refs/heads/docs/sg-35-test-helper
 if git push -q local HEAD:refs/heads/bad >/dev/null 2>&1; then exit 1; fi
 if git push -q local HEAD:refs/heads/fix/sg-2-valid HEAD:refs/heads/invalid >/dev/null 2>&1; then exit 1; fi
 [ -z "$(git --git-dir="$scratch/remote" for-each-ref refs/heads/fix/sg-2-valid)" ]
 git tag v1.2.3
 git push -q local refs/tags/v1.2.3
 git tag bad
 if git push -q local refs/tags/bad >/dev/null 2>&1; then exit 1; fi
 git push -q local :refs/heads/docs/sg-35-test-helper
 printf '(delete) 0000 refs/heads/invalid 1234\n' > "$scratch/input"
 if .githooks/pre-push < "$scratch/input" >/dev/null 2>&1; then exit 1; fi
 printf 'bad-input\n' > "$scratch/input"
 if .githooks/pre-push < "$scratch/input" >/dev/null 2>&1; then exit 1; fi
 # Explicitly exercise maintenance opt-in, without editing the repository binding.
 printf "\nSUPPORTED_MAINTENANCE='release/1.2.x'\n" >> .workflow/grammar.sh
 ./tools/workflow/check-ref branch release/1.2.x
 if ./tools/workflow/check-ref branch release/2.0.x; then exit 1; fi
)
printf 'PASS: %s grammar cases; helper, multi-ref push, alias, tag, delete, malformed input and maintenance opt-in integration cases\n' "$count"
