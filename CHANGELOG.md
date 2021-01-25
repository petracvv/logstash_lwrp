# logstash_lwrp Cookbook CHANGELOG

This file is used to list changes made in each version of the logstash_lwrp cookbook.

## Unreleased

## v2.1.0 (2021-01-24)

- Fix for YAML not being loaded by default in newer chef 16 versions
- Remove Ubuntu 16.04 as a tested platform (EOL in April)

## v2.0.0 (2020-07-21)

- Update to support Chef 16
- Bump required chef version to v15.8

## v1.2.0 (2019-06-10)

- Update to support Logstash 7.x
- Add ChefSpec test coverage
- Add systemd_unit_content property to logstash_service for custom systemd unit config
- Update to latest Circle CI test workflow

## v1.1.0 (2019-02-17)

- Add template variables property for logstash_pipeline.
- Add Circle CI tests for all supported platforms.

## v1.0.1 (2018-11-18)

- Add CONTRIBUTING.md file
- Reformat README so rendering works on github and supermarket

## v1.0.0 (2018-11-18)

Initial release.

- Added logstash_install resource
- Added logstash_config resource
- Added logstash_pipeline resource
- Added logstash_service resource
- Added Initial README
- Added LICENSE
- Added Integration tests
