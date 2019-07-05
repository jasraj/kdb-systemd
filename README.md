# systemd Notification Interface for kdb

This repository provides a kdb library to integrate with `systemd`. It provides the following features:

* Support for `Type=Notify` systemd services, providing READY and STOPPING signals
* Support for `WatchdogSec=` systemd watchdog monitoring
  * NOTE: This requires the kdb+ process to be the main process started by systemd. Use `exec` instead of backgrounding a process

An example systemd service file is provided in the repository.

NOTE: This library requires the shared object `libkdbsystemd.so` provided by the [kdb-systemd-lib](https://github.com/jasraj/kdb-systemd-lib) repository. Please ensure that this object is available in your target environment.

This library has been written for use with the [kdb-common](https://github.com/BuaBook/kdb-common) set of libraries.

## Building `libkdbsystemd.so`

See [kdb-systemd-lib](https://github.com/jasraj/kdb-systemd-lib) for build instructions

## Using the Notification Library

It is recommended to specify where the `libkdbsystemd.so` shared library is located by setting the `KSL_SO_FOLDER` environment variable. The library will then use that library on initialisation.

When the library is loaded and `.sdi.init` is executed (see kdb-common [require.q](https://github.com/BuaBook/kdb-common/wiki/require.q) for more details), the following initialisation is performed:

1. Attempt to discover the full path of the required shared object (`libkdbsystemd.so`)
1. The systemd interface functions are loaded from the shared object into the `.sdi.so` namespace.

### `.sdi.onProcessReady[]`

This function should be called after the process initialistion phases is complete and you want to report back to systemd that the process is ready for use. This function also:

1. Configures the systemd watchdog (i.e. heartbeat) if configured in the systemd file (using the kdb-common [cron.q](https://github.com/BuaBook/kdb-common/wiki/cron.q) library)
1. Configures notifying systemd when the process is about to exit (using the kdb-common [event.q](https://github.com/BuaBook/kdb-common/wiki/event.q) library)

### `.sdi.sendStatus[status]`

This function allows you to send custom status strings to systemd for more detailed reporting.

Example:

```
q) .sdi.sendStatus "Status from kdb+"

> systemctl status kdb-service
   Active: active (running) since Fri 2019-07-05 13:48:33 BST; 29s ago
 Main PID: 8801 (q)
   Status: "Status from kdb+"
```
