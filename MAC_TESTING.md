# Playtesting "Castle in the Sky" on a Mac (MacBook Air)

The game has no Windows-only code, so it runs on macOS as it is. I could not run Godot or a Mac here, so both options below are untested: if a step does not match what you see, tell me and I will fix it.

## Option A (easiest, about 5 minutes): your friend opens the project in Godot

1. On the Mac, download **Godot 4.7.2** (the standard version, not ".NET") from godotengine.org -> Download -> macOS. Unzip it and drag **Godot** into Applications. It is one universal app for Apple Silicon and Intel.
2. Send the whole project folder: zip your project folder (the one with `project.godot`, without the hidden `.godot` folder) and send it, or let your friend download the repository as a zip from GitHub (green "Code" button -> "Download ZIP") and unzip it.
3. Open Godot -> **Import** -> pick the `project.godot` file -> **Import & Edit**. The first import takes a minute.
4. Press the **Play** button (top right) or **Cmd+B**.
5. First time macOS may say Godot is from the internet: choose Open.

Controls on a MacBook: W A S D to move, mouse or trackpad to aim and fire. Pinch or two-finger scroll on the trackpad zooms the view. Press `fn` + F-key only if the function keys are needed; Esc opens the pause menu.

## Option B: build a double-clickable Mac app with GitHub (no Mac needed)

One-time setup in your own Godot (on your PC):

1. **Project -> Export -> Add... -> macOS.** Leave the preset name as **macOS**.
2. On that preset set:
   - **Application -> Bundle Identifier:** something like `com.yourname.castleinthesky`
   - **Binary Format -> Architecture:** `universal`
   - **Code Signing -> Codesign:** `Built-in (ad-hoc only)` if you see that option
   - **Notarization:** off
3. If Godot says export templates are missing, click **Manage Export Templates -> Download and Install**.
4. Save. This creates `export_presets.cfg` in the project folder. Commit it to GitHub together with the `.github` folder from this zip.

Then, every time you want a Mac build:

1. GitHub page of the repository -> **Actions** -> **Export macOS build** -> **Run workflow**.
2. When the run is green, open it and download **CastleInTheSky-macOS** at the bottom (under "Artifacts").
3. Your friend unzips it twice (GitHub's zip, then the game's zip) and gets **CastleInTheSky.app**.

Because the app is not signed by Apple, macOS blocks it at first. Your friend must do ONE of these:
- **Right-click** the app -> **Open** -> **Open** (do not just double-click the first time), or
- open Terminal and run: `xattr -cr ~/Downloads/CastleInTheSky.app` (use the real path), then double-click it.

If macOS says the app is "damaged", the Terminal command above fixes it.

## Performance tip for a MacBook Air

This is a 2D game, so the lightest renderer is enough. In Godot: **Project -> Project Settings -> Rendering -> Renderer -> Rendering Method = Compatibility** (restart the editor). It uses less battery and runs cooler. Check the game still looks the same before you commit it.

## Where saves go on a Mac

`~/Library/Application Support/Godot/app_userdata/<project name>/` (settings.cfg and the save slots). Your friend's saves are separate from yours.
