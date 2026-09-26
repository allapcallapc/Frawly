# Changelog

## [0.7.0](https://github.com/allapcallapc/Frawly/compare/v0.6.0...v0.7.0) (2026-09-26)


### Features

* hide vacant containers by default in Empty containers list ([#30](https://github.com/allapcallapc/Frawly/issues/30)) ([73c770e](https://github.com/allapcallapc/Frawly/commit/73c770ed3c8ee8e0f2423a3c0f5eeef92a9a4261))
* show selected count on empty containers button ([#31](https://github.com/allapcallapc/Frawly/issues/31)) ([c02aaf7](https://github.com/allapcallapc/Frawly/commit/c02aaf7663383ae6f50a7c3b4b0aa0fd601959be))


### Bug Fixes

* pin Empty containers button to the bottom of the screen ([#29](https://github.com/allapcallapc/Frawly/issues/29)) ([0b46984](https://github.com/allapcallapc/Frawly/commit/0b4698497dd976f3d5e2fff7ba559e2588cd96fb))

## [0.6.0](https://github.com/allapcallapc/Frawly/compare/v0.5.0...v0.6.0) (2026-09-22)


### Features

* give the Frawly MCP connector an icon ([318ede7](https://github.com/allapcallapc/Frawly/commit/318ede773a7103fac3b07af848ac9169e5bcea62))


### Bug Fixes

* compare the passphrase in constant time ([#25](https://github.com/allapcallapc/Frawly/issues/25)) ([ffe82ad](https://github.com/allapcallapc/Frawly/commit/ffe82ad9b3b7cd2163a79f932eec69024d9a461b)), closes [#21](https://github.com/allapcallapc/Frawly/issues/21)
* escape % and _ in the /containers search param ([#26](https://github.com/allapcallapc/Frawly/issues/26)) ([552ba2e](https://github.com/allapcallapc/Frawly/commit/552ba2ebb1bbc632e15ae936aec8e32ede9105b1)), closes [#22](https://github.com/allapcallapc/Frawly/issues/22)
* reject negative from/to in POST /containers/range ([#23](https://github.com/allapcallapc/Frawly/issues/23)) ([ee76d3b](https://github.com/allapcallapc/Frawly/commit/ee76d3b1a86c1fc293a2351de3718d949693417b)), closes [#19](https://github.com/allapcallapc/Frawly/issues/19)
* respect bottom system nav/gesture inset on every screen ([#18](https://github.com/allapcallapc/Frawly/issues/18)) ([7454b1a](https://github.com/allapcallapc/Frawly/commit/7454b1a2f93eada15e823c4dff9bf351f9f6b122))
* URL-encode container id when building ContainerService request paths ([#24](https://github.com/allapcallapc/Frawly/issues/24)) ([5ed8e7a](https://github.com/allapcallapc/Frawly/commit/5ed8e7a9abb8d05fe8358a3d34131865f3b2fb82))

## [0.5.0](https://github.com/allapcallapc/Frawly/compare/v0.4.0...v0.5.0) (2026-09-21)


### Features

* redesign home and summary screens with a card-based UI ([#16](https://github.com/allapcallapc/Frawly/issues/16)) ([34a7c52](https://github.com/allapcallapc/Frawly/commit/34a7c52c471a57c8acd89857142f495ef5cac45d))
* retheme app with colors sampled from the logo ([#15](https://github.com/allapcallapc/Frawly/issues/15)) ([c20b428](https://github.com/allapcallapc/Frawly/commit/c20b42859ee509a313c1440c81b2f8ee64fd8b3d))
* update app logo ([#14](https://github.com/allapcallapc/Frawly/issues/14)) ([aee9794](https://github.com/allapcallapc/Frawly/commit/aee9794fa12c2485c9e01cb7b601623d718f6f74))


### Bug Fixes

* rename app from Freezer Log to Frawly throughout the UI ([#13](https://github.com/allapcallapc/Frawly/issues/13)) ([8fba686](https://github.com/allapcallapc/Frawly/commit/8fba686c51e3c9c92df86c5a5f6045ea444f2260))

## [0.4.0](https://github.com/allapcallapc/Frawly/compare/v0.3.0...v0.4.0) (2026-09-20)


### Features

* check for and install app updates from GitHub Releases (Android) ([#10](https://github.com/allapcallapc/Frawly/issues/10)) ([0fe9d8a](https://github.com/allapcallapc/Frawly/commit/0fe9d8a8e1bb9aa68d05166f7dea6afc40482796))

## [0.3.0](https://github.com/allapcallapc/Frawly/compare/v0.2.0...v0.3.0) (2026-09-20)


### Features

* add an MCP server, hosted as a Cloudflare Worker ([#8](https://github.com/allapcallapc/Frawly/issues/8)) ([ad980f0](https://github.com/allapcallapc/Frawly/commit/ad980f0159c6ab634c4bc2590a8eae6d5ead1c51))


### Bug Fixes

* containers disappearing after reload (deferred load() race) + surface load errors ([#7](https://github.com/allapcallapc/Frawly/issues/7)) ([ae079a7](https://github.com/allapcallapc/Frawly/commit/ae079a7bf2357f85f4c2b40718601e74e92f2f4e))

## [0.2.0](https://github.com/allapcallapc/Frawly/compare/v0.1.0...v0.2.0) (2026-09-19)


### Features

* scaffold Freezer Log Flutter app with a Cloudflare Worker + D1 backend ([#1](https://github.com/allapcallapc/Frawly/issues/1)) ([bab496c](https://github.com/allapcallapc/Frawly/commit/bab496cbe3fabebf2e4d4f32a4455e7ae7051993))


### Bug Fixes

* backend CORS + connect screen autofill ([#4](https://github.com/allapcallapc/Frawly/issues/4)) ([e81f715](https://github.com/allapcallapc/Frawly/commit/e81f715756bfadc06b50b1cc026786a921807bf1))
* drop D1 trigger that breaks remote migrations ([#3](https://github.com/allapcallapc/Frawly/issues/3)) ([53e17d1](https://github.com/allapcallapc/Frawly/commit/53e17d10a309f53f4427aecd877c12a834ca8644))
