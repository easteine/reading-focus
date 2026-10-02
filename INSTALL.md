# Reading Focus — Installation Guide

A macOS menu bar app that locks you into one app and window for distraction-free reading.

## Install

Build the app, then copy it to Applications (`build.sh` also prints one-time code-signing setup steps):

```bash
./build.sh
cp -r ReadingFocus.app /Applications/
open /Applications/ReadingFocus.app
```

A book icon will appear in your menu bar.

---

## One-time setup

### 1. Accessibility permission

On first session start the app will prompt you automatically. If it does not appear, grant it manually:

**System Settings → Privacy & Security → Accessibility → add ReadingFocus**

This is required to fullscreen your chosen window and keep it in focus during a session.

### 2. Do Not Disturb shortcuts

Open the **Shortcuts** app and create two shortcuts:

| Name | Action |
|---|---|
| `Reading Mode On` | Set Focus → Do Not Disturb → Turn On (Until turned off) |
| `Reading Mode Off` | Set Focus → Do Not Disturb → Turn Off |

The app runs these automatically when a session starts and ends. If they do not exist, everything else still works — you just will not get automatic Do Not Disturb.

---

## Using the app

1. Click into the window you want to read so it is in front, then click the book icon in your menu bar. The menu shows what it will lock to ("Locks to: Preview — paper.pdf")
2. Pick a duration — 15 min, 30 min, 45 min, 1 hr, 90 min, 2 hr, or enter a custom number of minutes
3. That window enters full screen automatically (if it was already full screen, it stays that way when the session ends)
4. A countdown timer appears in the menu bar
5. If you switch to another app, you are immediately redirected back. If you quit the locked app, the session ends
6. Trackpad swipes that switch spaces (three/four-finger left/right and up) are turned off for the session and restored when it ends. If the app crashes mid-session, your original gesture settings are restored the next time it launches
7. When the timer ends you receive a notification and the session resets
8. To end early, click the menu bar icon and select **Stop Session**

---

## Rebuild after making changes

From the project folder:

```bash
./build.sh
```
