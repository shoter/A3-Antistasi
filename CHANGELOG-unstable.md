# Unstable changelog

Every push to `unstable` adds one entry at the top of this file, newest first. The release workflow
publishes the top entry as the body of the `unstable-latest` GitHub prerelease and the Steam workflow
publishes it as the Workshop change note, so write it for players. Format and rules: [CLAUDE.md](CLAUDE.md).

## 2026-09-05 - Town upgrades

### Added
- Town upgrades: the commander buys an upgrade kit for a rebel-held town in the Buy Vehicle dialog (new tab, price grows with the town's population). Rebels carry or truck the crate to that town and build it within 100 m of the centre. Clinic (+0.1 support per tick, civilian deaths hurt support half as much), market (+10% money), recruitment office (+10% HR), radio relay (counts as a rebel radio tower), militia post (garrison limit x1.5) and safehouse (free, faster fast travel and a 'lie low' action that clears undercover heat). One of each per town, shown as map markers and in the Towns tab. Upgrades are lost when the town falls, is destroyed, or is left unguarded during an invader punishment raid. Kits in transit and installed upgrades are stored in the campaign save.

### Fixed
- The police station multiplier on town support changes never applied because of an undefined variable. Towns without a police station now gain support 1.5x faster, as intended.

## 2026-09-05 - Helicopter air taxi

### Added
- Air Taxi in the Battle Command menu (Y), Player tab: charter a garaged transport or civilian helicopter. An AI pilot flies in from the nearest friendly airbase or the HQ, lands next to you, waits up to 60 s for you and your squad to board, flies you to any location marker you pick on the map and brings the helicopter back to the garage. No landing zone at the destination means a 3 m hover drop. The fare is 200 PLN plus 100 PLN per km from your own money, plus 1 HR for the pilot, refunded when he makes it home. A taxi that never picks you up refunds everything; a taxi shot down on the way loses the fare, the HR and the helicopter. Any marker can be the destination, enemy-held ones included, but garrisons along the route wake up as you fly over them.

### Changed
- The Player tab's button column now scrolls, so more buttons fit.

## 2026-09-05 - Players tab

### Added
- Players tab in the Battle Command menu (Y), open to every player: everyone who ever joined the campaign, online or offline, with kills, deaths, K/D and time online. Sort by clicking a column, narrow the list with the name filter, and press Details for one player's full record: vehicle, aircraft, civilian, friendly and player kills, longest kill, times downed, revives, sessions, first and last seen, current session, plus rank, score, money, money earned and missions completed. Admins also see the Steam UID.
- The statistics are tracked on the server and stored in the campaign save. They survive a player declining to load their personal save and are written on every autosave, so a crash loses at most one autosave interval. Kills count enemy soldiers only, everything else is in Details. Revives are counted for the Antistasi revive system, not for ACE medical.

### Changed
- The Battle Command tab strip now holds seven tabs.

## 2026-09-05 - Campaign chronicle

### Added
- Chronicle tab in the Battle Command menu (Y), readable by every player: a timeline of the campaign. It records sites and towns captured, lost or changing hands between the enemies, incoming attacks and whether they were repelled, punishments, HQ attacks and defences, HQ moves, Petros' death, promotions, war level changes and the end of the campaign. Entries name the rebel players who were there, show how long ago it happened, can be filtered by category, and a double-click jumps to the place on the map. The last 300 events are kept and stored in the campaign save.

### Changed
- The Battle Command tab buttons are narrower so that six tabs fit in the strip.

## 2026-09-05 - Player statistics and release notes

### Added
- Players tab in the main menu: everyone who ever joined the campaign, online or not, with kills, deaths, K/D and time online, sortable by column. A Details button opens the full record of one player: vehicle, air, civilian, friendly and player kills, longest kill, times downed, revives, money earned, sessions, first and last seen, plus rank, score, money and missions.
- Player statistics are tracked on the server, credited the same way the rest of Antistasi credits kills (including revive finishes and roadkills), and stored in the campaign save. They are flushed on every autosave, so a server crash loses at most one autosave interval.

### Internal
- Every push to `unstable` now carries its own release notes: the top entry of `CHANGELOG-unstable.md` is published in the `unstable-latest` GitHub prerelease and as the Steam Workshop change note. See `CLAUDE.md`.

## 2026-09-05 - Fork baseline

Everything this fork added on top of Antistasi 3.11.1 before this changelog existed.

### Added
- Junkyard at the HQ garage crate: buy heavily damaged civilian and military vehicles, restocked hourly. Wrecks get no free repairs for 10 hours and are marked as junk in the garage.
- Wreck stripping: engineers with a toolkit can strip any destroyed vehicle for scrap worth 1-3% of its junkyard price (at least 50 PLN). Wrecks inside a spawned enemy base have to wait until it is captured or cleared.
- Commander-deployable rally flag with a free, faster teleport from the HQ flag. One flag at a time, removable only at the flag or at the HQ flag.
- Battle Command menu: new Towns tab with town statistics and a new Garrisons tab.
- The commander can set how mission rewards are split.
- Automatic builds: every push to `unstable` publishes the `unstable-latest` GitHub prerelease and updates the Steam Workshop item.

### Changed
- Currency symbol changed from € to PLN.
- Loot crates no longer have a capacity limit when looting to crate.
