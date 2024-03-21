fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios get_dev_certs

```sh
[bundle exec] fastlane ios get_dev_certs
```

Get certificates

### ios build_unsigned_debug

```sh
[bundle exec] fastlane ios build_unsigned_debug
```

Build unsigned debug

### ios build_unsigned_dev_release

```sh
[bundle exec] fastlane ios build_unsigned_dev_release
```

Build unsigned dev release

### ios build_unsigned_prod_release

```sh
[bundle exec] fastlane ios build_unsigned_prod_release
```

Build unsigned prod release

### ios sign_dev_release

```sh
[bundle exec] fastlane ios sign_dev_release
```

Sign dev release

### ios sign_prod_release

```sh
[bundle exec] fastlane ios sign_prod_release
```

Sign prod release

### ios upload_apple_store

```sh
[bundle exec] fastlane ios upload_apple_store
```

Upload apple store

### ios ui_tests

```sh
[bundle exec] fastlane ios ui_tests
```

Run UI tests

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
