// systemd Notification Interface
// Copyright (c) 2018 - 2021 Jaskirat Rajasansir

.require.lib each `time`type`so`os`event;


/ The kdb <-> systemd shared object name
.sdi.cfg.soName:`libkdbsystemd.so;

/ The target local namespace for the shared object functions
.sdi.cfg.soTargetNs:`.sdi.so;

/ Configuration to load the shared object functions into the kdb process
.sdi.cfg.soFunctionMap:(`symbol$())!`long$();
.sdi.cfg.soFunctionMap[`sendReady]:     1;
.sdi.cfg.soFunctionMap[`sendStopping]:  1;
.sdi.cfg.soFunctionMap[`getInterval]:   1;
.sdi.cfg.soFunctionMap[`sendWatchdog]:  1;
.sdi.cfg.soFunctionMap[`sendStatus]:    1;
.sdi.cfg.soFunctionMap[`sendMainPid]:   1;
.sdi.cfg.soFunctionMap[`extendTimeout]: 1;

/ The list of supported OS types for 'systemd' integration
.sdi.cfg.systemdSupportedOs:`l`v;


/ Logs the 'systemd' state transitions based on the functions called in this library
/  @see .sdi.i.sendReady
/  @see .sdi.sendStopping
.sdi.state:`state xkey flip `state`transitionAt!"SP"$\:();


.sdi.init:{
    if[not .os.type in .sdi.cfg.systemdSupportedOs;
        .log.if.info "systemd is not supported on the current OS [ OS: ",string[.os.type]," ]";
        :(::);
    ];

    .sdi.i.loadNativeFunctions[];

    `.sdi.state upsert (`starting; .time.now[]);
 };


/ Signals to systemd that the current process is now ready. It also configures the watchdog (if required in the systemd
/ file) and will bind the stopping notification to the 'process.exit' event
/  @see .sdi.i.sendReady
/  @see .sdi.i.configureWatchdog
/  @see .sdi.i.setStoppingOnProcessExit
.sdi.onProcessReady:{
    .sdi.i.sendReady[];
    .sdi.i.configureWatchdog[];
    .sdi.i.setStoppingOnProcessExit[];
 };

/ Sends the stopping notification to systemd. This is bound to the process.exit event
/  @see .sdi.so.sendStopping
.sdi.sendStopping:{
    .log.if.debug "Notifying systemd that kdb application is stopping";
    `.sdi.state upsert (`stopping; .time.now[]);

    .sdi.so.sendStopping[];
 };

/ Sends an arbitrary status string to systemd
/  @param (Symbol|String) The status to send to systemd
/  @see .sdi.so.sendStatus
.sdi.sendStatus:{[status]
    .log.if.debug "Sending systemd status [ Status: ",.type.ensureString[status]," ]";
    .sdi.so.sendStatus status;
 };

/ Sends the main PID of the application to systemd
/  @param pid (Integer) Null to send the current pid ('.z.i') or a PID if a different 'primary' process
/  @see .sdi.so.sendMainPid
.sdi.sendMainPid:{[pid]
    $[null pid;
        pid:.z.i;
    not .type.isInteger pid;
        '"IllegalArgumentException"
    ];

    .log.if.debug ("Sending main PID to systemd [ PID: {} ]"; pid);
    .sdi.so.sendMainPid pid;
 };

.sdi.extendTimeout:{[extension]
    if[not .type.isTimespan extension;
        '"IllegalArgumentException";
    ];

    currentState:last[0!.sdi.state]`state;

    .log.if.info ("Extending systemd timeout [ Current State: {} ] [ Extension: {} ]"; currentState; extension);
    .sdi.so.extendTimeout currentState;
 };

/ Binds the stopping notification to the process.exit event
/  @see .sdi.sendStopping
.sdi.i.setStoppingOnProcessExit:{
    .log.if.info "Setting systemd 'stopping' notification on process exit";
    .event.addListener[`process.exit; `.sdi.sendStopping];
 };

/ Loads the shared object functions via the 'so' library and copies the function definitions into a library-local namespace
/  @see .sdi.cfg.soName
/  @see .sdi.cfg.soTargetNs
/  @see .sdi.cfg.soFunctionMap
.sdi.i.loadNativeFunctions:{
    .log.if.info "Loading systemd functions from shared object [ Shared Object: ",string[.sdi.cfg.soName]," ]";

    targetFuncs:` sv/: .sdi.cfg.soTargetNs,/: key .sdi.cfg.soFunctionMap;
    soFuncs:get each .so.loadFunction[.sdi.cfg.soName;] ./: flip (key; value) @\: .sdi.cfg.soFunctionMap;

    (set) ./: targetFuncs,'soFuncs;
 };

/ Sends the ready notification to systemd. This is performed on library initialisation
/  @see .sdi.so.sendReady
.sdi.i.sendReady:{
    .log.if.info "Notifying systemd that kdb application is ready";
    `.sdi.state upsert (`ready; .time.now[]);

    .sdi.so.sendReady[];
 };

/ Configures the systemd watchdog if enabled in the systemd file. See the associated systemd service file as an example.
/ The watchdog interval is half the interval reported back from the systemd to reduce the chance of being killed accidentally
/  @see .sdi.so.getInterval
/  @see .sdi.i.sendWatchdog
/  @see .cron.addRepeatForeverJob
.sdi.i.configureWatchdog:{
    wdInterval:.sdi.so.getInterval[];

    if[0D = wdInterval;
        .log.if.info "Application is not configured for watchdog monitoring in systemd. Nothing to do";
        :(::);
    ];

    / Only load 'cron' library if watchdog is required
    .require.lib`cron;

    / Send the watchdog every half interval to make sure we don't get killed accidentally
    sendWdInterval:`timespan$wdInterval % 2;

    .log.if.info "Configuring systemd watchdog monitoring [ Interval: ",string[wdInterval]," ] [ Send Every: ",string[sendWdInterval]," ]";

    .cron.addRepeatForeverJob[`.sdi.i.sendWatchdog; ::; .time.now[] + 00:00:01; sendWdInterval];
 };

/ Sends the systemd watchdog (or heartbeat). Includes a trace log for debugging
/  @see .sdi.so.sendWatchdog
.sdi.i.sendWatchdog:{
    .log.if.trace "Sending systemd watchdog";
    .sdi.so.sendWatchdog[];
 };
