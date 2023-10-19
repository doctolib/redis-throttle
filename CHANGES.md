# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Added Redis 7.2 to the list of actively supported engine versions

### Removed

- Drop Ruby 2.7 support

## [2.0.1] - 2023-10-19

### Fixed

- Don't fail on release if given list of strategies has only rate-limits.
  ([#24](https://gitlab.com/ixti/redis-throttle/-/issues/24))

## [2.0.0] - 2023-04-11

### Added

- Add support for redis-client.

### Changed

- (BREAKING) RedisThrottle.new now does not accept `redis` client, instead it's
  now required to pass it to `#call`, `#acquire`, `#release`, `#reset`, `#info`,
  and `.info`.

### Removed

- (BREAKING) Removed `redis/throttle.rb` and `Redis::Throttle` class.
  Use `redis_throttle.rb` and `RedisThrottle` instead.
- (BREAKING) Removed `RedisThrottle#|` alias of `#merge`.
- (BREAKING) Removed `RedisThrottle#<<` alias of `#merge!`.
- (BREAKING) Removed support of ConnectionPool - pass unpooled redis client
  instead.

## [1.1.0] - 2023-04-10

### Added

- Support Ruby-3.x.

### Changed

- Rename `Redis::Throttle` to `RedisThrottle`.

### Deprecated

- Using `Redis::Throttle` is now deprecated and will print out warning.
  To silence deprecation warnings set:
  `Redis::Throttle.silence_deprecation_warning = true`

## [1.0.0] - 2020-09-14

### Changed

- Refactor API and underlying Lua scripts to be more reliable.

## [0.0.1] - 2020-08-17

- Initial release. Effectively this version represents extraction of concurrency
  and threshold strategies from [sidekiq-throttled](https://github.com/ixti/sidekiq-throttled).

[unreleased]: https://gitlab.com/ixti/redis-throttle/-/compare/v2.0.1...main
[2.0.1]: https://gitlab.com/ixti/redis-throttle/-/compare/v2.0.0...v2.0.1
[2.0.0]: https://gitlab.com/ixti/redis-throttle/-/compare/v1.1.0...v2.0.0
[1.1.0]: https://gitlab.com/ixti/redis-throttle/-/compare/v1.0.0...v1.1.0
[1.0.0]: https://gitlab.com/ixti/redis-throttle/-/compare/v0.0.1...v1.0.0
[0.0.1]: https://gitlab.com/ixti/redis-throttle/-/commit/b5647214f5202a52e457adb354d26d3ab8fe7c50
