# 📻 Radiojoy for Omarchy 😇

An [Omarchy](https://omarchy.org) theme for **Alastor × Emily** (Hazbin Hotel), [also for Windows](#windows-10--11), where
the whole desktop follows the wallpaper. Put up an Alastor wallpaper and you get
Alastor's colours, art and quotes everywhere; an Emily one gives you Emily's; a
Radiojoy one gives you both.

![Alastor, Emily, Radiojoy](docs/order.jpg)

## What you get

| | Alastor wallpaper | Emily wallpaper | Radiojoy wallpaper |
|---|---|---|---|
| **Window border** | crimson → gold → maroon | periwinkle → lavender → halo blue | crimson → gold → periwinkle |
| **Terminal splash** | Radio Demon + 1930s Alastor | Emily + her six-winged form | Alastor + Emily |
| **Lock screen** | both his forms at the sides | both her forms | the two of them |
| **Screensaver** | his silhouettes | hers | both |
| **Bar button** | 📻 radio + devil | feather + sparkles | radio + heart + feather |
| **Spotify** (Spicetify) | maroon & gold | twilight periwinkle | theme colours |
| **Bar, menus, notifications** | maroon | twilight navy | theme colours |
| **Terminal colours** | crimson on maroon | lavender on twilight | theme colours |
| **Zen / Firefox** (opt-in) | maroon & crimson | twilight & halo blue | theme colours |

- **57 wallpapers** in a repeating Alastor → Emily → Radiojoy order (19 of each): official
  show stills for Alastor and Emily, and Radiojoy fan art, included with the artists'
  permission (see [Fan art](#fan-art)). The radio button on the bar goes to the next one.
- **Radiojoy Week:** during the week in `radiojoy-week.txt` (2026: Oct 18–24) the bar
  button wears a ★ and shows the day's prompt, and the terminal shows it too; the rest
  of the year it counts down. While Spotify plays, the button goes **on air**.
- **Radiojoy Week wallpaper:** during the week your wallpaper becomes a collage of that
  week's art with the prompt list beside it, finished days crossed out. It's locked for
  the week (the lock screen shows it too); the week's art only appears in the collage,
  not as separate wallpapers. An hourly timer
  adds new pieces as the artists post them and switches the wallpaper to the new collage
  when it changes; to check right away, left-click the radio button on the bar (it tells
  you what's new, or that nothing is yet). After the week it's removed.
  Got a piece before the artist posted it? `radiojoy-week --add FILE "ARTIST" DAY` (the
  name as in the artists file) puts it in now; when they post it, the posted copy
  replaces it instead of showing twice. List the artists in
  `~/.config/omarchy/themes/radiojoy/radiojoy-week-artists.txt` (Bluesky or Tumblr
  accounts, only ones you've checked draw by hand); RadioJoy Enjoyer and termsandfeathers
  are listed already. With none, it shows just the prompts.
  When the week is over the collage stays in the wallpaper carousel as a keepsake
  ("Radiojoy Week 2026"), with all of the week's art.
- **Next year's week:** once a day it looks for an upcoming Radiojoy Week, reading the
  dates and prompts off the announcement banner (OCR). Where it looks: the Bluesky and
  Tumblr accounts in `radiojoy-week-artists.txt`, DeviantArt's public search and
  Bluesky's public search. Weeks found in your listed artists' posts are added to
  `radiojoy-week.txt` (with a notification to check the prompts, since OCR can misread a
  word); search finds, which anyone can post, are only suggested:
  `radiojoy-week --accept YYYY-MM-DD` adds one.
- **New week artists:** during the week it also searches Bluesky for accounts posting
  week art that aren't listed yet (skipping fic posts and posts labelled NSFW) and
  sends a notification with links. Check that they draw by hand, then
  `radiojoy-week --add-artist HANDLE` adds them to the collage.
- **Terminal splash:** the art is drawn as a real image beside fastfetch and "tunes in"
  through radio static, with a quote and a little status line under it. Terminals you haven't typed in yet redraw when the wallpaper changes.
- **Lock screen:** every time you lock, the background steps to the next wallpaper in the order.
- A radio "tuning in" sound at login.

![Lock screen](docs/lock-screen.png)

![Terminal splash art](docs/splash-art.png)

## Install

Needs Omarchy (Hyprland, Lua config) and bash. Terminal images need a terminal with
sixel support (foot, the Omarchy default, works); others get a text version.

```bash
git clone https://github.com/blade361/omarchy-radiojoy
cd omarchy-radiojoy
./install.sh
```

The installer copies the theme, scripts, bar button and a small background service,
adds python-pillow, python-numpy and tesseract (OCR) if missing, and switches to the theme.

| Option | |
|---|---|
| `--no-lock` | keep your current lock screen |
| `--no-splash` | don't add the terminal splash to `~/.bashrc` |
| `--no-spotify` | skip the Spotify extension |

Switching to another theme puts your borders, screensaver and lock background back to
normal; the splash and bar button only appear while Radiojoy is active.

### Lock screen

The installer clones Omarchy's own lock screen (`<you>.lock`) and adds the Radiojoy art
to it. If you already use a custom lock screen it's left alone, and so is a newer Omarchy
whose lock code has changed; everything else still works.

### Spotify

Only with [Spicetify](https://spicetify.app). The installer adds the `radiojoy-follow.js`
extension and runs `spicetify apply` once (Spotify restarts). After that, colours change
live without restarting.

### Zen / Firefox

Add this as the first line of your profile's `chrome/userChrome.css` (and enable
`toolkit.legacyUserProfileCustomizations.stylesheets` in `about:config`):

```css
@import url("radiojoy-zen.css");
```

The colours update with the wallpaper and apply the next time the browser starts.

## Uninstall

```bash
omarchy theme set tokyo-night   # any other theme
./uninstall.sh
```

## Windows 10 / 11

Most of the theme also runs on Windows, from the `windows/` folder. Download the repo
(**Code → Download ZIP**), unzip it and double-click **`windows\install.cmd`**. Nothing is
installed system-wide and no admin rights are needed; it all lives in
`%LOCALAPPDATA%\Radiojoy`. The Windows version is new: if something doesn't work, please
[open an issue](https://github.com/blade361/omarchy-radiojoy/issues).

The desktop still follows the wallpaper: a small background program (the 📻 tray icon,
started at login) watches it and switches everything over. Putting up a wallpaper
that isn't one of the theme's turns it all off, the way switching themes does on Omarchy.

| | Windows |
|---|---|
| **Wallpapers** | all 57, same order; click the tray icon for the next one |
| **Window borders & title bars** | Windows 11: the focused window's border runs through the character's gradient, title bars in their colours. Windows 10: accent-coloured title bars |
| **Accent colour** | Start, taskbar and accent follow the wallpaper; dark mode on |
| **Terminal splash** | PowerShell profile: the art beside the system info ([fastfetch](https://github.com/fastfetch-cli/fastfetch) if installed), tuning in through static, quote and status line. Real images need Windows Terminal 1.22 or newer (sixel); older terminals get the text version |
| **Terminal colours** | Windows Terminal schemes *Radiojoy*, *Radiojoy Alastor*, *Radiojoy Emily* and a *Radiojoy* profile; open terminals switch palette at their next prompt |
| **Lock screen** | steps one wallpaper along the order on every lock, with the character art at the sides and the tagline |
| **Tray icon** (the bar button) | the character's heads, a red dot while Spotify plays (on air); right-click for a quote and Radiojoy Week |
| **Spotify** | with [Spicetify](https://spicetify.app), live like on Linux (not the Microsoft Store Spotify, which Spicetify can't patch) |
| **Zen / Firefox** | same `@import` line as below, in the profile under `%APPDATA%` |
| **Sounds** | the login sound, and each character's notification sound |
| **Radiojoy Week** | today's prompt in the tray and the splash. The collage wallpaper needs [Python](https://www.python.org) with Pillow (the installer offers to add Pillow); Tesseract OCR is optional, for finding next year's week |

Not on Windows: the screensaver (Windows screensavers are programs), redrawing the
splash in terminals you haven't typed in yet, the bar/menu colours, and the boot logo.

Options for `install.ps1` (run it from PowerShell with
`powershell -ExecutionPolicy Bypass -File windows\install.ps1 -NoSounds`, for example):
`-NoSplash`, `-NoSpotify`, `-NoAccent`, `-NoBorders`, `-NoSounds`, `-NoWeek`, `-Yes`.
The splash needs PowerShell to run your profile; if it isn't allowed to, the installer
asks to set `RemoteSigned` for your user (the usual setting for this).

To uninstall, run `%LOCALAPPDATA%\Radiojoy\uninstall.ps1` the same way. It puts back
your wallpaper, colours, sound, profile and Spotify theme. If you used Windows
Spotlight on the lock screen, turn it back on in Settings → Personalization → Lock screen.

## Fan art

The Radiojoy wallpapers are fan art, included **with each artist's permission**. Each one
has the artist's name in the corner. They're not covered by the MIT licence. Please don't
repost them; follow the artists and find their work at the links below.

- Dragonfoxgirl ([DeviantArt](https://www.deviantart.com/dragonfoxgirl)): [Holy Light](https://www.deviantart.com/dragonfoxgirl/art/Holy-Light.-1273980120),
  [Oops](https://www.deviantart.com/dragonfoxgirl/art/Oops-1262499961),
  [She Listens](https://www.deviantart.com/dragonfoxgirl/art/She-Listens.-1347366914),
  [You Promised To Be Good!](https://www.deviantart.com/dragonfoxgirl/art/You-Promised-To-Be-Good%21-1260603204),
  [Your concern is wasted on this Little Dove](https://www.deviantart.com/dragonfoxgirl/art/Your-concern-is-wasted-on-this-Little-Dove-1341538897),
  [Annoying little angel on my shoulder](https://www.deviantart.com/dragonfoxgirl/art/Annoying-little-angel-on-my-shoulder-1277248105),
  [Al Al Al!](https://www.deviantart.com/dragonfoxgirl/art/Al-Al-Al%21-1233950345)
- RadioJoy Enjoyer ([Bluesky](https://bsky.app/profile/radiojoyenjoyer.bsky.social), X @RadioJoyEnjoyer):
  [Doodling!](https://bsky.app/profile/radiojoyenjoyer.bsky.social/post/3mxxnxxevzk2x),
  [My parents](https://bsky.app/profile/radiojoyenjoyer.bsky.social/post/3msyqfqud2227),
  [Emily](https://bsky.app/profile/radiojoyenjoyer.bsky.social/post/3mlb76mwsek2m),
  [cuddles](https://bsky.app/profile/radiojoyenjoyer.bsky.social/post/3mjmjphmstk22);
  Radiojoy Week 2026 [Day 1 "Fallen Emily"](https://bsky.app/profile/radiojoyenjoyer.bsky.social/post/3my6zctsua227)
  and [Day 2 "Dove/Shadow"](https://bsky.app/profile/radiojoyenjoyer.bsky.social/post/3myayejcjqs2e) (in the week collage)
- termsandfeathers ([Tumblr](https://termsandfeathers.tumblr.com)): [cherry blossoms](https://www.tumblr.com/termsandfeathers/814820394436640768),
  [50 followers Q+A](https://www.tumblr.com/termsandfeathers/816085258794614784),
  ["This is dangerous"](https://www.tumblr.com/termsandfeathers/812903677665968128);
  Radiojoy Week 2026 [Day 1](https://www.tumblr.com/termsandfeathers/830853127253196800)
  and [Day 2](https://www.tumblr.com/termsandfeathers/830907476634451968) sketches (in the week collage)
- Pikagalaxy30: [Alastor x Emily](https://www.deviantart.com/pikagalaxy30/art/Alastor-x-Emily-%28Hazbin-Hotel%2C-Radiojoy%29-1267936052)
- OctoDemon: [RadioJoy](https://www.deviantart.com/octodemon/art/RadioJoy-1381048921)
- MadridStone: [Date Night](https://www.deviantart.com/madridstone/art/Date-Night-%28RadioJoy%29-1332050081)
- sPitter: [Feral Alastor giving Emily a lift](https://www.deviantart.com/spitter/art/Feral-Alastor-giving-Emily-a-lift-1327810953)

## Credits

- Hazbin Hotel, Alastor and Emily © Vivienne Medrano / A24 / Prime Video. The Alastor and
  Emily wallpapers, character renders and stills come from the [Hazbin Hotel wiki](https://hazbinhotel.fandom.com).
  This is an unofficial fan project.
- The lock screen builds on Omarchy's lock plugin ([MIT](https://github.com/basecamp/omarchy)).
- The scripts, theme files and login sound in this repo are MIT licensed (see LICENSE).
  The art is not; it belongs to its owners (show art) and the artists above (fan art).
