# systemd Notification Interface for kdb

This repository provides a kdb library to integrate with `systemd`. It provides the following features:

* Support for `Type=Notify` systemd services, providing READY and STOPPING signals
* Support for `WatchdogSec=` systemd watchdog monitoring

An example systemd service file is provided in the repository.

NOTE: This library requires the shared object `libkdbsystemd.so` provided by the [kdb-systemd-lib](https://github.com/jasraj/kdb-systemd-lib) repository. Please ensure that this object is loaded and available in your target environment.

This library has been written for use with the [kdb-common](https://github.com/BuaBook/kdb-common) set of libraries.

## Building `libkdbsystemd.so`

See [kdb-systemd-lib](https://github.com/jasraj/kdb-systemd-lib) for build instructions

## Using the Notification Library
