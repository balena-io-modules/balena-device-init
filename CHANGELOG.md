# Change Log

All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/).

## v4.0.1 - 2017-11-21

- Move from travis to circle and set up npm autopublishing

## v4.0.0 - 2017-10-13

### Changed

- Take config as an argument to `configure`, rather than generating it ourselves
- Expect `appUpdatePollInterval` in milliseconds, not seconds, and don't stringify it

## v3.0.0 - 2017-04-17

### Changed

- Added a required `deviceApiKey` parameter to `configure`
- Updated to resin-device-config ^4.0.0

## v2.2.1 - 2017-04-14

### Fixed

- Node v4 support

## v2.2.0 - 2017-03-28

### Changed

- Updated dependencies to pull in etcher-image-writer@^9.

## v2.1.1 - 2017-01-24

### Changed

- Moved to [resin-sdk-preconfigured](https://github.com/resin-io-modules/resin-sdk-preconfigured)

## v2.1.0 - 2016-09-14

- Attempt to get `device-type.json` from the image's first partition.

## v2.0.4 - 2016-04-08

- Support shorter uuids.

## v2.0.3 - 2016-03-22

- Upgrade `resin-device-config` to v3.0.0.

## v2.0.2 - 2015-12-05

- Omit tests from NPM package.

## v2.0.1 - 2015-10-12

- Upgrade to Resin SDK v3.0.0.

## v2.0.0 - 2015-09-30

- Take a device type instead of a uuid in `initialize()`.

## v1.0.4 - 2015-09-08

- Upgrade `resin-device-operations` to v1.2.5.

### Changed

## v1.0.3 - 2015-09-07

### Changed

- Upgrade `resin-device-config` to v2.1.0.

## v1.0.2 - 2015-09-07

### Changed

- Upgrade `resin-device-config` to v2.0.1.

## v1.0.1 - 2015-09-07

### Changed

- Upgrade `resin-device-operations` to v1.2.4.
