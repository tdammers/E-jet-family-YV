var getCruiseModeValue = func (key, weight, cruiseAlt) {
    var model = getModel();
    if (model == nil) { return nil; }
    if (weight == nil) {
        weight = (getprop('/fdm/jsbsim/inertia/weight-lbs') or 60000) * LB2KG;
    }
    var tablekey = sprintf("%s/%s", model, key);
    var table = loadTable2DH(tablekey);
    return lookupTable(table, [ weight, cruiseAlt ]);
};

var getWindCorrection = func (ci, wind) {
    var model = getModel();
    var tablekey = sprintf("%s/CI_wind", model);
    var table = loadTable2DH(tablekey);
    return lookupTable(table, [wind or 0, ci or 0]);
};

var getCruiseEconMach = func (ci, altitude = nil, weight = nil, wind = 0) {
    var model = getModel();
    if (altitude == nil) {
        altitude = getprop('/autopilot/route-manager/cruise/altitude-ft') or 27000;
    }
    if (weight == nil) {
        weight = (getprop('/fdm/jsbsim/inertia/weight-lbs') or 60000) * LB2KG;
    }
    if (wind != nil) {
        ci += getWindCorrection(ci or 0, wind or 0) or 0;
    }
    var tablekey = sprintf("%s/CI", model);
    var table = loadTable3DH(tablekey);
    return lookupTable(table, [ altitude, weight, ci ]);
};

var updateCruiseSpeeds = func () {
    var cruiseAlt = getprop('/autopilot/route-manager/cruise/altitude-ft') or 0;
    var currentAlt = getprop('/instrumentation/altimeter/indicated-altitude-ft') or 0;
    var alt = math.max(5000, cruiseAlt, currentAlt);
    var mach = 0.76;
    var ias = 240;

    # LRC
    mach = getCruiseModeValue("LRC_Mach", nil, alt) or 0.76;
    ias = getCruiseModeValue("LRC_IAS", nil, alt) or 250;
    setprop('fms/cruise-speeds/mlrc', mach);
    setprop('fms/cruise-speeds/vlrc', ias);

    # MXR SPD
    # No data available for MXR SPD; we'll assume that LRC is based on MXR plus
    # 4%, so we derive MXR as being 4% slower than LRC.
    mach = math.round(mach * 96) / 100;
    ias = math.round(ias * 0.96);
    setprop('fms/cruise-speeds/mmxr', mach);
    setprop('fms/cruise-speeds/vmxr', ias);

    # MAX END
    mach = getCruiseModeValue("MHold", nil, alt) or 0.6;
    ias = getCruiseModeValue("VHold", nil, alt) or 210;
    setprop('fms/cruise-speeds/mmxe', mach);
    setprop('fms/cruise-speeds/vmxe', ias);
};

