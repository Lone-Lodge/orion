# packages/ — studio-shared astra modules

Script packages shared ACROSS Lone Lodge games, without being
engine-standard. The resolution ladder for `use NAME`:

    1. the game's own scripts/        (game identity, rule-bearing)
    2. this directory                 (studio-shared libraries)
    3. atlas/packages/                (engine-standard, ships with atlas)

Wire a game up in its <game>.toml:

    packages = "../packages ../atlas/packages"

Rules of the house:
- Packages are fn/const/component LIBRARIES only. Rule-bearing
  scripts (`on`/`when`) stay in the game — a package pulled into N
  bundles would fire its rules N times.
- A package graduates: game script -> here when a second game wants
  it -> atlas/packages when it leans on engine conventions and
  should version with the engine.
- Hot reload works through every tier.
