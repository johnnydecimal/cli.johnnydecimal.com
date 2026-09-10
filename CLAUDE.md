## Git branching

- Work goes on `dev/<title>`, where `<title>` names the work: `dev/ops-manual-routing`, not `dev/johnny`.
- `dev/johnny` is an integration branch. It holds work merged from elsewhere; it is not where work is done.
  - It's okay to commit small fixes to `dev/johnny`.
  - If we're on it and about to do real work, say so and propose a `dev/<title>` branched from it.
- **Check `git branch --show-current` before every commit, and name the branch when you report the commit.** Never trust the branch from earlier in the session. I switch branches in another window, so the ground moves under you between turns.
- Before any merge or push, compare the current branch against `origin/main` _and_ the other local `dev/*` branches. Work split across two branches without either of us noticing is the failure that actually happens.
- If a branch's name stops describing what we're doing, stop and say so.
