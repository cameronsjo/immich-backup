---
status: awaiting-merge
issue: https://github.com/cameronsjo/immich-backup/issues/1
---

# Reap health CGI children

## Goal

Stop the health endpoint from accumulating zombie CGI processes while preserving the image's cron behavior and `/cgi-bin/health` contract.

## Chosen approach

Install Alpine's `tini` package and make `tini` PID 1, with the existing entrypoint as its child. `tini` will forward signals and reap orphaned CGI children while `crond` continues to run in the foreground beneath it.

## Alternatives declined

- Replacing the CGI endpoint would change a documented orchestration interface and duplicate health-state logic elsewhere.
- Requiring consumers to set Compose `init: true` would leave the published image defective by default.

## Checklist

- [x] Add `tini` to the runtime image and put it at the entrypoint boundary.
- [x] Add a container-level regression test that probes health repeatedly and fails if zombie children accumulate.
- [x] Run the shell and container verification gates.
- [x] Update the changelog.
- [ ] Merge pull request #5; issue #1 closes automatically.

## Next step

Merge [pull request #5](https://github.com/cameronsjo/immich-backup/pull/5), publish the main-branch image, recreate the deployed container, and confirm repeated health probes leave no zombies.
