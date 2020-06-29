// systemd Notification Interface
// Copyright (c) 2018 Jaskirat Rajasansir

.require.lib each `time`type`file;
.require.lib each `os`event;


/ The name of the shared object to find
.sdi.cfg.soName:`libkdbsystemd;

/ The environment variable to check for a path to the shared object location
.sdi.cfg.soPathEnvVar:`KSL_SO_FOLDER;

/ Configuration to load the shared object functions into the kdb process
.sdi.cfg.nativeFunctionMap:`kdbFunc xkey flip `kdbFunc`nativeFunc`args!"SSJ"$\:();
.sdi.cfg.nativeFunctionMap[`.sdi.so.sendReady]:   (`sendReady; 1);
.sdi.cfg.nativeFunctionMap[`.sdi.so.sendStopping]:(`sendStopping; 1);
.sdi.cfg.nativeFunctionMap[`.sdi.so.getInterval]: (`getInterval; 1);
.sdi.cfg.nativeFunctionMap[`.sdi.so.sendWatchdog]:(`sendWatchdog; 1);
.sdi.cfg.nativeFunctionMap[`.sdi.so.sendStatus]:  (`sendStatus; 1);

/ The list of supported OS types for 'systemd' integration
.sdi.cfg.systemdSupportedOs:`l`v;


/ Once discovered, the full path to the shared object
.sdi.soPath:`;


.sdi.init:{
    if[not .os.type in .sdi.cfg.systemdSupportedOs;
        .log.if.info "systemd is not supported on the current OS [ OS: ",string[.os.type]," ]";
        :(::);
    ];

    .sdi.soPath:.sdi.cfg.soName;

    if[not "" ~ getenv .sdi.cfg.soPathEnvVar;
        .sdi.soPath:.sdi.i.getCustomSoPath[];
    ];

    .sdi.i.loadNativeFunctions[];
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
    .sdi.so.sendStopping[];
 };

/ Sends an arbitrary status string to systemd
/  @param (Symbol|String) The status to send to systemd
/  @see .sdi.so.sendStatus
.sdi.sendStatus:{[status]
    .log.if.debug "Sending systemd status [ Status: ",.type.ensureString[status]," ]";
    .sdi.so.sendStatus status;
 };


/ Attempts to derive the custom location of the shared object based on the path set in the environment variable. If the
/ specified folder does not contain the shared object, the function will look for 'lib' and 'lib64' folders (based on the
/ current kdb process architecture)
/  @returns (FilePath) The full path to the shared object (without the .so suffix) for use with 2:
/  @see .sdi.cfg.soPathEnvVar
/  @see .sdi.cfg.soName
.sdi.i.getCustomSoPath:{
    customSoPath:`$":",getenv .sdi.cfg.soPathEnvVar;
    soFileName:` sv .sdi.cfg.soName,`so;

    if[soFileName in .file.ls customSoPath;
        .log.if.info "Shared object found in root of custom folder path [ Path: ",string[customSoPath]," ]";
        :` sv customSoPath,.sdi.cfg.soName;
    ];

    if[(`x86 = .util.getProcessArchitecture[]) & `lib in .file.ls customSoPath;
        .log.if.info "32-bit shared object found in 'lib' folder [ Path: ",string[customSoPath]," ]";
        :` sv customSoPath,`lib,.sdi.cfg.soName;
    ];

    if[(`x86_64 = .util.getProcessArchitecture[]) & `lib64 in .file.ls customSoPath;
        .log.if.info "64-bit shared object found in 'lib64' folder [ Path: ",string[customSoPath]," ]";
        :` sv customSoPath,`lib64,.sdi.cfg.soName;
    ];

    .log.if.error "Shared object could not be found within the custom folder path specified [ Path: ",string[customSoPath]," ]";
    '"MissingSharedObjectException";
 };

/ Binds the stopping notification to the process.exit event
/  @see .sdi.sendStopping
.sdi.i.setStoppingOnProcessExit:{
    .log.if.info "Setting systemd 'stopping' notification on process exit";
    .event.addListener[`process.exit; `.sdi.sendStopping];
 };

/ Loads and maps the native functions available in the shared object to kdb functions
/ @see .sdi.cfg.nativeFunctionMap
.sdi.i.loadNativeFunctions:{
    .log.if.info "Loading native functions [ Shared Object: ",string[.sdi.soPath]," ] [ Native Functions: ",string[count .sdi.cfg.nativeFunctionMap]," ]";

    {[kdbFunc]
        soFunc:.sdi.cfg.nativeFunctionMap kdbFunc;

        .log.if.debug "Loading native function [ kdb: ",string[kdbFunc]," ] [ Native: ",.Q.s1[soFunc]," ]";

        set[kdbFunc; .sdi.soPath 2: value soFunc];
    } each exec kdbFunc from .sdi.cfg.nativeFunctionMap;
 };

/ Sends the ready notification to systemd. This is performed on library initialisation
/  @see .sdi.so.sendReady
.sdi.i.sendReady:{
    .log.if.info "Notifying systemd that kdb application is ready";
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
