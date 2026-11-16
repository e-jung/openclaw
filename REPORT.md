# PR #200297 — live native WebKit before/after

Tested 2026-11-16 UTC. PR: https://github.com/openclaw/openclaw/pull/200297 · Issue: https://github.com/openclaw/openclaw/issues/200283

## Result

**The reload regression reproduces on the merge-base and is prevented on the PR head, in both a native WKWebView and Safari.** Each client/build was tested with native Control+primary clicks on three different sidebar session links.

**Qualification:** both clients delivered `contextmenu` in this environment. The exact reported variant with *no* `contextmenu` was **not reproduced**. This proves the real navigation failure and its fix on native WebKit, but does not prove that missing-event variant inside OpenClaw.app itself (which was intentionally not touched).

| Client | Build | Full document navigation/reload | Session menu after gesture | `contextmenu` fired |
| --- | --- | --- | --- | --- |
| Native WKWebView | merge-base | Yes, 3/3 | No retained menu; navigation dismisses it | Yes, 3/3 |
| Native WKWebView | PR head | No, 0/3 | Yes, 3/3 | Yes, 3/3 |
| Safari | merge-base | Yes, 3/3 | No retained menu; navigation dismisses it | Yes, 3/3 |
| Safari | PR head | No, 0/3 | Yes, 3/3 | Yes, 3/3 |

“Reload” here means a new document caused by following the anchor. Navigation Timing labels it `navigate`, not the literal `reload` type. Time origin changes, document-load traces (WKWebView), `beforeunload` (Safari), and Gateway WebSocket replacement substantiate this distinction. The base context-menu handler prevents the `contextmenu` default, but the subsequent `click` remains uncanceled and follows the href.

## Versions and isolation

- macOS **26.7.2**, build **25G332**, on the M4 Mac mini.
- System WebKit **21624.5.1.11.3**. Harness UA: `Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko)`.
- Safari **27.2** (application-reported version).
- Fix: **2d9ccf1ddbad341e82f36f9bfe50337b0e20fc2e**, branch `fix/macos-ctrl-click-sidebar-reload`.
- Base: **f947bdc94981e299fe26b5a71af8bfdd4e7ac125**, `git merge-base origin/main HEAD` at test setup.
- OpenClaw **2026.11.4**, built separately in each checkout with `pnpm ui:build`; the launcher built each checkout's runtime. Exact metadata: [fix](fix-ui-build-info.json), [base](base-ui-build-info.json). Head metadata has `dirty:true` because preexisting untracked PR drafts were present; no product source was changed.
- Gateway ports **19480** (fix), **19481** (base), loopback only. Separate temporary HOME, OPENCLAW_HOME, state, config, workspace, generated auth token; clean subprocess environment. Channels/providers, plugins, cron, discovery, automatic updates/catalog refresh, browser-control server, and canvas host disabled for this fixture. See redacted config files and build/startup logs.
- Each gateway ran in an owned `systemd-run --user --scope` cgroup (`oc-proof-fix.scope`, `oc-proof-base.scope`). A separate SSH reverse-forward exposed only these loopback ports to the mini.
- The production gateway, its port, installed dist, service, OpenClaw.app, node, launchd jobs, and tunnel were not changed or restarted. No PR comment, edit, push, or source patch was made.

## Method

1. Created a detached negative-control worktree with an independently installed frozen-lockfile dependency tree. Built both UIs and runtimes from their respective checkouts. Build logs retain advisory UI performance warnings.
2. Started isolated gateways with disposable auth tokens. Loaded the supported `#token=…` bootstrap URL. Seeded three empty sessions through authenticated `sessions.create` RPCs (`key`, `label` only, no message/task/model call); replies report `runStarted:false`.
3. Opened an explicit session using `/chat?session=agent:main:proof-1`, which canonicalizes to `/chat/main/proof-1`. This avoids first-run model-setup routing without configuring a provider or running inference.
4. Compiled [Proof200283.swift](Proof200283.swift), an AppKit NSWindow + ordinary WKWebView with `isInspectable=true`. A document-end user script passively records trusted native pointer/mouse/click/contextmenu events to sessionStorage and a native JSONL log; a document-start WebSocket wrapper exposes the socket solely to seed supported RPCs. The harness has no custom context-menu suppression and no new-window delegate.
5. Drove actual Control+left-clicks with the paired computer tool (`text:"ctrl"`), after confirming the target app/window. Event logging did not synthesize, cancel, or suppress any gesture. Cleared menu with Escape between fixed-build clicks. Tested Cmd+click (`text:"cmd"`) separately.
6. Safari's AppleScript automation permission prompt was declined. Instead, temporarily enabled its developer features through Safari Settings, injected an equivalent passive event logger in the visible Develop console, then exported only the proof-owned sessionStorage data via console `copy()` and `pbpaste`. Reinstalled the logger after each base navigation. Restored developer features to disabled afterward.
7. Saved computer-tool screenshots directly; SSH `screencapture` was unavailable in that SSH context (`could not create image from display`). All supplied screenshots are actual Mac desktop captures from the computer tool.

## Event evidence

Representative trusted native sequence in **both** clients:

```text
pointerdown button=0 ctrlKey=true metaKey=false
mousedown   button=0 ctrlKey=true metaKey=false
contextmenu button=0 ctrlKey=true metaKey=false
  contextmenu after: defaultPrevented=true
mouseup     button=0 ctrlKey=true metaKey=false
click       button=0 ctrlKey=true metaKey=false
  BASE click after: defaultPrevented=false -> href followed -> new document
  FIX  click after: defaultPrevented=true  -> menu remains -> same document
```

WKWebView document origins (milliseconds; WebKit may round by 1 ms):

| Case | Before | After |
| --- | ---: | ---: |
| Fix Control-clicks 1–3 | 1794872188448 | 1794872188448 / 1794872188448 / 1794872188449 |
| Base Control-click 1 | 1794872339047 | 1794872367193 |
| Base Control-click 2 | 1794872367193 | 1794872384902 |
| Base Control-click 3 | 1794872384902 | 1794872403879 |

Safari document origins:

| Case | Before | After |
| --- | ---: | ---: |
| Fix Control-clicks 1–3 | 1794872282727 | 1794872282727 |
| Base Control-click 1 | 1794872407036 | 1794872468439 |
| Base Control-click 2 | 1794872468439 | 1794872513836 |
| Base Control-click 3 | 1794872513836 | 1794872539976 |

Full raw traces: `wk-{base,fix}-click{1,2,3}.json` (cumulative per WK build); `safari-base-click{1,2,3}.json` (one gesture each); [Safari fix](safari-fix-clicks.json) (three gestures); [native log](native-events.jsonl); [summary](SUMMARY.json).

The WK logger's generic `menu` boolean checks only whether any `.session-menu` element exists; this class is also used by the header trigger/hidden shell. **Do not use that boolean as visibility evidence.** Visible menus are established by screenshots; navigation/retention is established independently by document origins and events. WK `beforeunload` was not observed for these navigations; Safari logged it for all three base gestures.

## Command-click regression

- **WKWebView fix:** `metaKey=true`, `ctrlKey=false`; `click.defaultPrevented=false`; no session context menu opened. The bare harness follows the link in its current WKWebView (it has no new-window delegate), replacing the document. [Trace](wk-fix-cmd.json), [screenshot](wk-fix-cmd.png).
- **Safari fix:** same uncanceled modified click, **opens an additional background tab**, no session context menu, original document origin unchanged. [Trace](safari-fix-cmd.json), [screenshot](safari-fix-cmd.png).

## Screenshots

- WK merge-base: [before](wk-base-before.png), [after navigation, no menu](wk-base-after.png).
- WK PR head: [before](wk-fix-before.png), [menu retained](wk-fix-after.png).
- Safari: [base before](safari-base-before.png), [fixed menu retained](safari-fix-after.png).

## Gateway-log corroboration

The logs report Control UI build IDs matching each checkout, and every base gesture replaces the Gateway socket. Example base WK first gesture:

```text
23:39:27.161 [ws] webchat disconnected ... WebSocket is closed due to suspension.
23:39:27.379 [ws] client connected ... build=2026.11.4-f947bdc94981-2026-11-16T23-27-31.649Z
```

Example base Safari first gesture:

```text
23:41:08.392 [ws] webchat disconnected ... WebSocket is closed due to suspension.
23:41:08.753 [ws] client connected ... build=2026.11.4-f947bdc94981-2026-11-16T23-27-31.649Z
```

Fix WK's Control-click interval stays on one socket between `23:36:28.743` and the separate Cmd+click at `23:37:49.594`. Fix Safari's three Control-clicks stay on its original socket; the later separate Cmd+click creates another tab/socket at `23:43:41.138`. Initial setup navigation, switching builds, and final cleanup naturally create other connections/disconnections.

See [base excerpts](base-ws-excerpts.log), [fix excerpts](fix-ws-excerpts.log), and the full sanitized gateway logs. Tokens are not included.

## Setup failures, limits, and cleanup

- A borrowed dependency symlink was rejected by the repository's install-ownership guard; replaced it with an independent install before building base.
- Base launcher initially timed out on the shared lifecycle lock; retried with a distinct `OPENCLAW_SYSTEMD_UNIT` identity. No managed service was stopped by the launcher.
- Initial fix startup rejected group-writable temporary ancestors; corrected only the disposable tree to owner-only permissions and restarted only the owned scope. Both final gateways reached ready and served the requested builds.
- No attempt was made to force or simulate missing `contextmenu`; that exact variant remains unverified.
- Both owned scopes stopped, cgroups empty/inactive; VPS ports 19480/19481 absent.
- Owned reverse SSH tunnel terminated; mini ports 19480/19481 absent.
- Native harness and Safari (which was not running before this task) stopped. Developer features restored to disabled (`IncludeDevelopMenu=0`).
- Mac harness directory/Swift file, VPS temporary HOME/state/config/workspaces/command files, and the owned merge-base worktree removed. Standard generated PR-checkout build artifacts and this evidence directory remain; no running service remains.
- Verification output: [cleanup](cleanup.txt).
