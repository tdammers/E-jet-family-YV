var getLRCMach = func (weight, cruiseAlt) {
    var model = getModel();
    if (model == nil) { return nil; }
    if (weight == nil) {
        weight = (getprop('/fdm/jsbsim/inertia/weight-lbs') or 60000) * LB2KG;
    }
    var tablekey = sprintf("%s/LRC_Mach", model);
    var table = loadTable2DH(tablekey);
    return lookupTable(table, [ weight, cruiseAlt ]);
};

var getLRCIAS = func (weight, cruiseAlt) {
    var model = getModel();
    if (model == nil) { return nil; }
    if (weight == nil) {
        weight = (getprop('/fdm/jsbsim/inertia/weight-lbs') or 60000) * LB2KG;
    }
    var tablekey = sprintf("%s/LRC_IAS", model);
    var table = loadTable2DH(tablekey);
    return lookupTable(table, [ weight, cruiseAlt ]);
};

var updateCruiseLRC = func () {
    var cruiseAlt = getprop('/autopilot/route-manager/cruise/altitude-ft') or 0;
    var currentAlt = getprop('/instrumentation/altimeter/indicated-altitude-ft') or 0;
    var alt = math.max(5000, cruiseAlt, currentAlt);
    var mach = getLRCMach(nil, alt);
    var ias = getLRCIAS(nil, alt);
    setprop('fms/cruise-speeds/mlrc', mach or 0.76);
    setprop('fms/cruise-speeds/vlrc', ias or 250);
};

var updateCruiseSpeeds = func () {
    updateCruiseLRC();
};
