# Changelog

Versions 1.1.0 and 1.2.1 were released before the project moved to Conventional Commits and have no changelog.

## [12.1.0](https://github.com/NatanielMarmucki/spiewnik-app/compare/v12.0.0...v12.1.0) (2026-09-21)


### Features

* **tablet:** larger text on tablets ([#54](https://github.com/NatanielMarmucki/spiewnik-app/issues/54)) ([0cfd976](https://github.com/NatanielMarmucki/spiewnik-app/commit/0cfd976eafcb51b3eae2a47fef83bc099083d9ec))

## 12.0.0 (2026-09-21)

### Features

* **search:** words in any order, stems, ranked results ([#51](https://github.com/NatanielMarmucki/spiewnik-app/issues/51)) ([e7498c6](https://github.com/NatanielMarmucki/spiewnik-app/commit/e7498c6e4417e14ec04657c92b95fbd3d75a3dd1))
* **song:** turn songs as pages, in the right direction ([#48](https://github.com/NatanielMarmucki/spiewnik-app/issues/48)) ([3771d7d](https://github.com/NatanielMarmucki/spiewnik-app/commit/3771d7d411c6038d21e4dfbd6ba89a998b0f0e33))
* **welcome:** say only the settings came over when that is all there was ([#40](https://github.com/NatanielMarmucki/spiewnik-app/issues/40)) ([91b7bbc](https://github.com/NatanielMarmucki/spiewnik-app/commit/91b7bbc4fd29e17af3680f42e2c2c25b5fec7d41))
* **welcome:** one-time welcome screen after the migration from the old iOS app ([#39](https://github.com/NatanielMarmucki/spiewnik-app/issues/39)) ([3ea39ff](https://github.com/NatanielMarmucki/spiewnik-app/commit/3ea39ffc5d1b53f27f6334d9ba3210e28949b571))
* close out the parity list before 12.0.0 ([#36](https://github.com/NatanielMarmucki/spiewnik-app/issues/36)) ([aecd987](https://github.com/NatanielMarmucki/spiewnik-app/commit/aecd987a2b6509b4847f3cfeb709e11516075cb2))
* **songs:** bring back fast scrolling on the songbook list ([#35](https://github.com/NatanielMarmucki/spiewnik-app/issues/35)) ([43affda](https://github.com/NatanielMarmucki/spiewnik-app/commit/43affda4bbe7bd8c561e5797a829d615aec55c57))
* **ios:** adopt the UIScene lifecycle ([#34](https://github.com/NatanielMarmucki/spiewnik-app/issues/34)) ([e8cde59](https://github.com/NatanielMarmucki/spiewnik-app/commit/e8cde594b26420666035192416ea83fe17a1ea22))
* redesign steps 4 and 5 — navigation, sheets, dialogs and accessibility ([#33](https://github.com/NatanielMarmucki/spiewnik-app/issues/33)) ([ea27230](https://github.com/NatanielMarmucki/spiewnik-app/commit/ea2723038dae5e9c1cb8ec0b046fecd05d19a0e8))
* **view:** rebuild the lists and the song text renderer ([#29](https://github.com/NatanielMarmucki/spiewnik-app/issues/29)) ([8b89a04](https://github.com/NatanielMarmucki/spiewnik-app/commit/8b89a04b1dcf35f098c71bef995b84f5f3684212))
* **theme:** add the design system tokens and theme ([#28](https://github.com/NatanielMarmucki/spiewnik-app/issues/28)) ([e1c9f17](https://github.com/NatanielMarmucki/spiewnik-app/commit/e1c9f17e8ef9551c305894ba3c720c0a8b483210))
* **search:** find songs regardless of Polish diacritics ([#15](https://github.com/NatanielMarmucki/spiewnik-app/issues/15)) ([750b681](https://github.com/NatanielMarmucki/spiewnik-app/commit/750b6817e538339e98f4c4e0c935e84b31708b3c))
* **my-songs:** sort user songs alphabetically in Polish order ([#14](https://github.com/NatanielMarmucki/spiewnik-app/issues/14)) ([1eecece](https://github.com/NatanielMarmucki/spiewnik-app/commit/1eececeddca1404b090edd87d69a7dd27fa9aa36))
* **migration:** migrate font size from the iOS app ([#10](https://github.com/NatanielMarmucki/spiewnik-app/issues/10)) ([ee00adc](https://github.com/NatanielMarmucki/spiewnik-app/commit/ee00adc553bf2044ec3457cd0bf35e46624c76d1))
* **migration:** migrate favorites and user songs from the iOS app ([#9](https://github.com/NatanielMarmucki/spiewnik-app/issues/9)) ([1834b52](https://github.com/NatanielMarmucki/spiewnik-app/commit/1834b52e395cb8cbd163ef599f8c08dc871876b5))
* **migration:** add reader for iOS app database ([#6](https://github.com/NatanielMarmucki/spiewnik-app/issues/6)) ([e9135ee](https://github.com/NatanielMarmucki/spiewnik-app/commit/e9135ee874967326babcf505e6c399dcafc9300d))
* **my-songs:** add my songs tab for user songs ([#4](https://github.com/NatanielMarmucki/spiewnik-app/issues/4)) ([00490b3](https://github.com/NatanielMarmucki/spiewnik-app/commit/00490b37e5509e9701d396774589b0180501a1b2))
### Bug Fixes

* **theme:** remove the shadow from the pill button ([#41](https://github.com/NatanielMarmucki/spiewnik-app/issues/41)) ([299922a](https://github.com/NatanielMarmucki/spiewnik-app/commit/299922a6e5ef4487b7c333139eb5b71b27810308))
* **songs:** shorten the rule next to the verse number ([cc81eee](https://github.com/NatanielMarmucki/spiewnik-app/commit/cc81eee10d9e24d7dcd8fffeff1b64df0eb3aeac))
* **song-detail:** keep the screen on after switching songs ([#16](https://github.com/NatanielMarmucki/spiewnik-app/issues/16)) ([e1f0f94](https://github.com/NatanielMarmucki/spiewnik-app/commit/e1f0f94b427f3cf8b15def948d476da244a1d2e2))
* **my-songs:** keep a stable order of user songs ([#13](https://github.com/NatanielMarmucki/spiewnik-app/issues/13)) ([831e439](https://github.com/NatanielMarmucki/spiewnik-app/commit/831e439bbc30a255d5da6f50a3cbf93d950d8f58))
* **songs:** fix song titles and texts for existing users ([#1](https://github.com/NatanielMarmucki/spiewnik-app/issues/1)) ([ef2d135](https://github.com/NatanielMarmucki/spiewnik-app/commit/ef2d1355efeb4c131efe515d59d312b1792f18a5))
### Performance Improvements

* **search:** keep the normalized song text in memory ([#50](https://github.com/NatanielMarmucki/spiewnik-app/issues/50)) ([a4dc8cb](https://github.com/NatanielMarmucki/spiewnik-app/commit/a4dc8cbd0ad0cf2c8b94bfd5fbe4d7a6d4555fc4))
