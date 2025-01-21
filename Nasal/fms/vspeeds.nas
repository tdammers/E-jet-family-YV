# V-Speed calculations

var calcMinV = func (which) {
    var model = getModel();
    if (model == nil) { return nil; }
    var toMode = getprop('/controls/flight/trs/to');
    if (toMode == nil) { toMode = 1; }
    toMode = math.min(2, math.max(1, toMode));
    var altitude = getprop('/fms/takeoff-conditions/pressure-alt');
    var oat = getprop('/fms/takeoff-conditions/oat');
    var tow = getprop('/fms/takeoff-conditions/weight-kg') or 0;
    if (tow < 1000) {
        tow = (getprop('/fdm/jsbsim/inertia/weight-lbs') or 60000) * LB2KG;
    }

    printf("--- Minimum %s calculation ---", which);
    printf("Aircraft:   %5s", model);
    printf("Thrust:      TO-%i", toMode);
    printf("OAT:        %5.0f°C", oat);
    printf("Press. alt: %5.0fft", altitude);
    printf("TOW:        %5.0fkg", tow);

    var tablekey = sprintf("%s/min%s_TO-%i", model, which, toMode);
    var table = loadTable3DH(tablekey);
    return lookupTable(table, [ altitude, oat, tow ]);
};

var calcV = func (which) {
    var model = getModel();
    if (model == nil) { return nil; }
    var toMode = getprop('/controls/flight/trs/to');
    if (toMode == nil) { toMode = 1; }
    toMode = math.min(2, math.max(1, toMode));
    var altitude = getprop('/fms/takeoff-conditions/pressure-alt');
    var oat = getprop('/fms/takeoff-conditions/oat');
    var tow = getprop('/fms/takeoff-conditions/weight-kg') or 0;
    if (tow < 1000) {
        tow = (getprop('/fdm/jsbsim/inertia/weight-lbs') or 60000) * LB2KG;
    }
    var flaps = math.min(4, math.max(1, math.round((getprop('/fms/takeoff-conditions/flaps') or 0.25) * 8)));

    printf("--- %s calculation ---", which);
    printf("Aircraft:   %5s", model);
    printf("Thrust:      TO-%i", toMode);
    printf("OAT:        %5.0f°C", oat);
    printf("Press. alt: %5.0fft", altitude);
    printf("TOW:        %5.0fkg", tow);
    printf("FLAPS:      FLAPS %i", flaps);

    var tablekey = '';
    var table = nil;

    tablekey = sprintf("%s/min%s_TO-%i", model, which, toMode);
    table = loadTable3DH(tablekey);
    var minV = lookupTable(table, [ altitude, oat, tow ]) or 0;

    tablekey = sprintf("%s/V1VRV2-column_TO-%i_FLAPS-%i", model, toMode, flaps);
    table = loadTable2D(tablekey);
    if (table == nil) {
        return minV;
    }
    var columnOffsets = { 'V1': 0, 'VR': 1, 'V2': 2 };
    var column = lookupTable(table, [ altitude, "~" ~ oat ]);
    if (column == nil or columnOffsets[which] == nil) {
        return minV;
    }
    column = column * 3 + columnOffsets[which];

    tablekey = sprintf("%s/V1VRV2_TO-%i_FLAPS-%i", model, toMode, flaps);
    table = loadTable2D(tablekey);
    var v = lookupTable(table, [ tow, "@" ~ column ]);

    if (v == nil or minV == nil) return nil;
    return math.max(minV, v);
};

var calcVFS = func (weight = nil) {
    var model = getModel();
    if (model == nil) { return nil; }
    if (weight == nil) {
        weight = (getprop('/fdm/jsbsim/inertia/weight-lbs') or 60000) * LB2KG;
    }
    var tablekey = sprintf("%s/VFS", model);
    var table = loadTable1D(tablekey);
    return lookupTable(table, [ weight ]);
};

var calcVAC = func (weight = nil) {
    var model = getModel();
    if (model == nil) { return nil; }
    if (weight == nil) {
        weight = (getprop('/fdm/jsbsim/inertia/weight-lbs') or 60000) * LB2KG;
    }
    var tablekey = sprintf("%s/VAC", model);
    var table = loadTable2DH(tablekey);
    var flapSetting = math.round(getprop('/fms/landing-conditions/approach-flaps') * 8);
    return lookupTable(table, [ weight, flapSetting ]);
};

var calcVref = func (weight = nil) {
    var model = getModel();
    if (model == nil) { return nil; }
    if (weight == nil) {
        weight = (getprop('/fdm/jsbsim/inertia/weight-lbs') or 60000) * LB2KG;
    }
    var icing = getprop('/fms/landing-conditions/ice-accretion');
    var tablekey = sprintf("%s/Vref-%s", model, icing ? 'ice' : 'noice');
    var table = loadTable2DH(tablekey);
    var flapSetting = math.round(getprop('/fms/landing-conditions/landing-flaps') * 8);
    return lookupTable(table, [ weight, flapSetting ]);
};

var takeoffPitchTable = [
    12.0, # FLAPS UP (not used)
    11.0, # FLAPS 1
    10.0, # FLAPS 2
    11.0, # FLAPS 3
    12.0, # FLAPS 4
    12.0, # FLAPS 5 (not used for T/O, same as FLAPS 4)
    13.0, # FLAPS FULL (not used for T/O)
];

var calcTakeoffPitch = func (weight = nil) {
    # TODO: figure out how weight factors in
    var flapSetting = math.round(getprop('/fms/takeoff-conditions/flaps') * 8);
    return takeoffPitchTable[flapSetting] or 8.0;
};

var update_departure_vspeeds = func () {
    var v1 = calcV('V1');
    var vr = calcV('VR');
    var v2 = calcV('V2');
    var vfs = calcVFS();
    var pitch = calcTakeoffPitch();
    printf("V1: %3.0f", (v1 == nil) ? "---" : v1);
    printf("VR: %3.0f", (vr == nil) ? "---" : vr);
    printf("V2: %3.0f", (v2 == nil) ? "---" : v2);
    printf("VFS: %3.0f", (vfs == nil) ? "---" : vfs);
    printf("PITCH: %4.1f", (pitch == nil) ? "---" : pitch);
    if (v1 != nil and v1 > 0) { setprop('/fms/vspeeds-calculated/departure/v1', v1); }
    if (vr != nil and vr > 0) { setprop('/fms/vspeeds-calculated/departure/vr', vr); }
    if (v2 != nil and v2 > 0) { setprop('/fms/vspeeds-calculated/departure/v2', v2); }
    if (vfs != nil and vfs > 0) { setprop('/fms/vspeeds-calculated/departure/vfs', vfs); }
    if (pitch != nil and pitch > 0) { setprop('/fms/vspeeds-calculated/departure/pitch', pitch); }
};

var update_approach_vspeeds = func () {
    var law = getprop('/fms/landing-conditions/weight-kg') or 0;
    var vac = calcVAC(law);
    var vref = calcVref(law);
    var vfs = calcVFS(law);
    var vappr = (vref == nil) ? nil : (vref + 10);
    if (vac != nil and vac > 0) { setprop('/fms/vspeeds-calculated/approach/vac', vac); }
    if (vref != nil and vref > 0) { setprop('/fms/vspeeds-calculated/approach/vref', vref); }
    if (vappr != nil and vappr > 0) { setprop('/fms/vspeeds-calculated/approach/vappr', vappr); }
    if (vfs != nil and vfs > 0) { setprop('/fms/vspeeds-calculated/approach/vfs', vfs); }
};

# setlistener("sim/signals/fdm-initialized", func {
#     setlistener('/fms/takeoff-conditions', func () { update_departure_vspeeds(); }, 1, 2);
#     setlistener('/controls/flight/trs/to', func () { update_departure_vspeeds(); }, 1, 0);
#     setlistener('/fms/landing-conditions', func () { update_approach_vspeeds(); }, 1, 2);
# });
