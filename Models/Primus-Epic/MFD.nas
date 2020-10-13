# E-Jet Family MFD
#
# AOM references:
# - TCAS mode: p. 2157

var mfd_display = [nil, nil];
var mfd = [nil, nil];
var DC = 0.01744;

var RouteDriver = {
    new: func(includeCurrent=1){
        var m = {
            parents: [RouteDriver],
        };
        m.includeCurrent = includeCurrent;
        return m;
    },

    update: func () {
        me.flightplans = [];
        if ((me.includeCurrent or fms.modifiedFlightplan == nil) and flightplan() != nil) {
            append(me.flightplans, { fp: flightplan(), type: 'current' });
        }
        if (fms.modifiedFlightplan != nil) {
            append(me.flightplans, { fp: fms.modifiedFlightplan, type: 'modified' });
        }
    },

    getNumberOfFlightPlans: func() {
        return size(me.flightplans);
    },

    getFlightPlanType: func(fpNum) {
        if (fpNum >= size(me.flightplans)) return nil;
        return me.flightplans[fpNum].type;
    },

    getFlightPlan: func(fpNum) {
        if (fpNum >= size(me.flightplans)) return nil;
        return me.flightplans[fpNum].fp;
    },

    getPlanSize: func(fpNum) {
        var fp = me.getFlightPlan(fpNum);
        if (fp == nil) return 0;
        return fp.getPlanSize();
    },

    getWP: func(fpNum, idx) {
        var fp = me.getFlightPlan(fpNum);
        if (fp == nil) return nil;
        return fp.getWP(idx)
    },

    getPlanModeWP: func(idx) {
        var fp = me.getFlightPlan(0);
        if (fp == nil) return nil;
        return fp.getWP(idx)
    },

    hasDiscontinuity: func(fpNum, wptID) {
        # todo
        return 0;
    },

    getListeners: func(){[
        "/fms/flightplan-modifications",
		"/autopilot/route-manager/active",
    ]},

    shouldUpdate: func 1
};

var MFD = {
    new: func(canvas_group, file, index = 0) {
        var m = { parents: [MFD] };
        m.init(canvas_group, file, index);
        return m;
    },

    init: func(canvas_group, file, index) {
        var font_mapper = func(family, weight) {
            return "LiberationFonts/LiberationSans-Regular.ttf";
        };

        var self = me; # for listeners

        me.index = index;
        me.elems = {};
        me.props = {
                'page': props.globals.getNode('/instrumentation/mfd[' ~ index ~ ']/page'),
                'heading': props.globals.getNode('/orientation/heading-deg'),
                'heading-mag': props.globals.getNode('/orientation/heading-magnetic-deg'),
                'track': props.globals.getNode('/orientation/track-deg'),
                'track-mag': props.globals.getNode('/orientation/track-magnetic-deg'),
                'heading-bug': props.globals.getNode('/it-autoflight/input/hdg'),
                'tas': props.globals.getNode('/instrumentation/airspeed-indicator/true-speed-kt'),
                'ias': props.globals.getNode('/instrumentation/airspeed-indicator/indicated-speed-kt'),
                'sat': props.globals.getNode('/environment/temperature-degc'),
                'tat': props.globals.getNode('/fdm/jsbsim/propulsion/tat-c'),
                'wind-dir': props.globals.getNode("/environment/wind-from-heading-deg"),
                'wind-speed': props.globals.getNode("/environment/wind-speed-kt"),
                'nav-src': props.globals.getNode("/instrumentation/pfd[" ~ index ~ "]/nav-src"),
                'nav-id': [
                    props.globals.getNode("/instrumentation/nav[0]/nav-id"),
                    props.globals.getNode("/instrumentation/nav[1]/nav-id"),
                ],
                'nav-loc': [
                    props.globals.getNode("/instrumentation/nav[0]/nav-loc"),
                    props.globals.getNode("/instrumentation/nav[1]/nav-loc"),
                ],
                'route-active': props.globals.getNode("/autopilot/route-manager/active"),
                'wp-dist': props.globals.getNode("/autopilot/route-manager/wp/dist"),
                'wp-ete': props.globals.getNode("/autopilot/route-manager/wp/eta-seconds"),
                'wp-id': props.globals.getNode("/autopilot/route-manager/wp/id"),
                'dest-dist': props.globals.getNode("/autopilot/route-manager/distance-remaining-nm"),
                'dest-ete': props.globals.getNode("/autopilot/route-manager/ete"),
                'dest-id': props.globals.getNode("/autopilot/route-manager/destination/airport"),
                'zulutime': props.globals.getNode("/instrumentation/clock/indicated-sec"),
                'cursor': props.globals.getNode("/instrumentation/mfd[" ~ index ~ "]/cursor"),
                'cursor.x': props.globals.getNode("/instrumentation/mfd[" ~ index ~ "]/cursor/x"),
                'cursor.y': props.globals.getNode("/instrumentation/mfd[" ~ index ~ "]/cursor/y"),
                'range': props.globals.getNode("/instrumentation/mfd[" ~ index ~ "]/lateral-range"),
                'tcas-mode': props.globals.getNode("/instrumentation/tcas/inputs/mode"),
            };

        var masterProp = props.globals.getNode("/instrumentation/mfd[" ~ index ~ "]");
        foreach (var key; ['show-navaids', 'show-airports', 'show-wpt', 'show-progress', 'show-missed', 'show-tcas']) {
            var node = masterProp.addChild(key);
            node.setBoolValue(0);
            me.props[key] = node;
        }

        me.master = canvas_group;

        # Upper area (lateral/systems): 1024x768
        me.upperArea = me.master.createChild("group");
        me.upperArea.set("clip", "rect(100px, 1024px, 868px, 0px)");
        me.upperArea.set("clip-frame", canvas.Element.PARENT);
        me.upperArea.setTranslation(0, 100);

        # Lower area (vertical/checklists): 1024x400
        me.lowerArea = me.master.createChild("group");
        me.lowerArea.set("clip", "rect(868px, 1024px, 1266px, 0px)");
        me.lowerArea.set("clip-frame", canvas.Element.PARENT);
        me.lowerArea.setTranslation(0, 868);

        me.guiOverlay = me.master.createChild("group");
        canvas.parsesvg(me.guiOverlay, "Aircraft/E-jet-family/Models/Primus-Epic/MFD-gui.svg", {'font-mapper': font_mapper});

        # Set up MAP/PLAN page
        me.dualRouteDriver = RouteDriver.new();
        me.plannedRouteDriver = RouteDriver.new(0);

        me.mapPage = me.upperArea.createChild("group");

        me.map = me.mapPage.createChild("map");
        me.map.set("clip", "rect(0px, 1024px, 740px, 0px)");
        me.map.set("clip-frame", canvas.Element.PARENT);
        me.map.setTranslation(512, 540);
        me.map.setController("Aircraft position");
        me.map.setRange(25);
        me.map.setScreenRange(416);
        me.map.addLayer(factory: canvas.SymbolLayer, type_arg: "TFC-Ejet", visible: 1, priority: 9,
                        style: {
                            'color_default':
                                [0.5,0.5,0.5],
                            'color_by_lvl': {
                                # 0: other
                                0: [0,1,1],
                                # 1: proximity
                                1: [0,1,1],
                                # 2: traffic advisory (TA)
                                2: [1,0.75,0],
                                # 3: resolution advisory (RA)
                                3: [1,0,0],
                            },
                        } );
        me.map.addLayer(factory: canvas.SymbolLayer, type_arg: "WPT", visible: 1, priority: 6,
                        opts: { 'route_driver': me.dualRouteDriver },);
        me.map.addLayer(factory: canvas.SymbolLayer, type_arg: "RTE", visible: 1, priority: 5,
                        opts: { 'route_driver': me.dualRouteDriver }, style: { 'line_dash_modified': func (arg=nil) { return [32,16]; } },);
        me.map.addLayer(factory: canvas.SymbolLayer, type_arg: "APT", visible: 1, priority: 4,);
        me.map.addLayer(factory: canvas.SymbolLayer, type_arg: "VOR", visible: 1, priority: 4,);
        me.map.addLayer(factory: canvas.SymbolLayer, type_arg: "NDB", visible: 1, priority: 4,);
        me.map.addLayer(factory: canvas.SymbolLayer, type_arg: "RWY", visible: 0, priority: 3,);
        me.map.addLayer(factory: canvas.SymbolLayer, type_arg: "TAXI", visible: 0, priority: 3,);
        # WXR layer is buggy.
        # me.map.addLayer(factory: canvas.SymbolLayer, type_arg: "WXR", visible: 0, priority: 1,);
        # TERR layer not available in FGDATA as of 2020.2
        # me.map.addLayer(factory: canvas.SymbolLayer, type_arg: "TERR", visible: 0, priority: 1,);
        me.map.hide();

        me.plan = me.mapPage.createChild("map");
        me.plan.set("clip", "rect(0px, 1024px, 640px, 0px)");
        me.plan.set("clip-frame", canvas.Element.PARENT);
        me.plan.setTranslation(512, 320);
        me.plan.setController("Static position");
        var (lat,lon) = geo.aircraft_position().latlon();
        me.plan.controller.setPosition(lat, lon);
        me.plan.setRange(25);
        me.plan.setScreenRange(416);
        me.plan.addLayer(factory: canvas.SymbolLayer, type_arg: "WPT", visible: 1, priority: 6,
                        opts: { 'route_driver': me.plannedRouteDriver },);
        me.plan.addLayer(factory: canvas.SymbolLayer, type_arg: "RTE", visible: 1, priority: 5,
                        opts: { 'route_driver': me.plannedRouteDriver }, style: { 'line_dash_modified': func (arg=nil) { return [32,16]; } },);
        me.plan.addLayer(factory: canvas.SymbolLayer, type_arg: "APT", visible: 1, priority: 4,);
        # TODO: figure out how to position the airplane symbol at the correct
        # position.
        # me.plan.addLayer(factory: canvas.SymbolLayer, type_arg: "APS", visible: 1, priority: 3,);
        me.planIndex = 0;

        me.mapOverlay = me.mapPage.createChild("group");
        canvas.parsesvg(me.mapOverlay, "Aircraft/E-jet-family/Models/Primus-Epic/MFD-map.svg", {'font-mapper': font_mapper});

        var mapkeys = [
                'arc',
                'arc.compass',
                'arc.heading-bug',
                'arc.heading-bug.arrow-left',
                'arc.heading-bug.arrow-right',
                'arc.master',
                'arc.range.left',
                'arc.range.right',
                'dest.dist',
                'dest.eta',
                'dest.fuel',
                'dest.fuel.unit',
                'dest.wpt',
                'eta-ete',
                'heading.digital',
                'nav.src',
                'nav.target',
                'nav.target.dist',
                'nav.target.ete',
                'nav.target.name',
                'next.dist',
                'next.eta',
                'next.fuel',
                'next.fuel.unit',
                'next.wpt',
                'plan.master',
                'plan.range',
                'progress.master',
                'sat.digital',
                'tas.digital',
                'tat.digital',
                'terrain.master',
                'tcas.master',
                'tcas.altmode',
                'tcas.mode',
                'weather.master',
                'wind.arrow',
                'wind.digital',
            ];
        var guikeys = [
                'mapMenu',
                'checkNavaids',
                'checkAirports',
                'checkWptIdent',
                'checkProgress',
                'checkMissedAppr',
                'checkTCAS',
                'radioWeather',
                'radioTerrain',
                'radioOff',
            ];
        foreach (var key; mapkeys) {
            me.elems[key] = me.mapOverlay.getElementById(key);
            if (me.elems[key] == nil) {
                debug.warn("Element does not exist: " ~ key);
            }
        }
        foreach (var key; guikeys) {
            me.elems[key] = me.guiOverlay.getElementById(key);
            if (me.elems[key] == nil) {
                debug.warn("Element does not exist: " ~ key);
            }
        }
        me.elems['arc'].set("clip", "rect(0px, 1024px, 540px, 0px)");
        me.elems['arc'].set("clip-frame", canvas.Element.PARENT);
        me.elems['arc'].setCenter(512, 530);
        me.elems['arc.heading-bug'].setCenter(512, 530);
        me.elems['mapMenu'].hide();

        me.widgets = [
            { key: 'btnMap', ontouch: func { self.touchMap(); } },
            { key: 'btnPlan', ontouch: func { self.touchPlan(); } },
            { key: 'btnSystems', ontouch: func { self.touchSystems(); } },
            { key: 'btnTCAS', ontouch: func { debug.dump("TCAS"); } },
            { key: 'btnWeather', ontouch: func { debug.dump("Weather"); } },
            { key: 'checkNavaids', active: func { self.elems['mapMenu'].getVisible() }, ontouch: func { self.toggleMapCheckbox('navaids'); } },
            { key: 'checkAirports', active: func { self.elems['mapMenu'].getVisible() }, ontouch: func { self.toggleMapCheckbox('airports'); } },
            { key: 'checkWptIdent', active: func { self.elems['mapMenu'].getVisible() }, ontouch: func { self.toggleMapCheckbox('wpt'); } },
            { key: 'checkProgress', active: func { self.elems['mapMenu'].getVisible() }, ontouch: func { self.toggleMapCheckbox('progress'); } },
            { key: 'checkMissedAppr', active: func { self.elems['mapMenu'].getVisible() }, ontouch: func { self.toggleMapCheckbox('missed'); } },
            { key: 'checkTCAS', active: func { self.elems['mapMenu'].getVisible() }, ontouch: func { self.toggleMapCheckbox('tcas'); } },
            { key: 'radioWeather', active: func { self.elems['mapMenu'].getVisible() }, ontouch: func { self.selectUnderlay('WX'); } },
            { key: 'radioTerrain', active: func { self.elems['mapMenu'].getVisible() }, ontouch: func { self.selectUnderlay('TERRAIN'); } },
            { key: 'radioOff', active: func { self.elems['mapMenu'].getVisible() }, ontouch: func { self.selectUnderlay(nil); } },
        ];

        forindex (var i; me.widgets) {
            var elem = me.guiOverlay.getElementById(me.widgets[i].key);
            var boxElem = me.guiOverlay.getElementById(me.widgets[i].key ~ ".clickbox");
            if (boxElem == nil) {
                me.widgets[i].box = elem.getTransformedBounds();
            }
            else {
                me.widgets[i].box = boxElem.getTransformedBounds();
            }
            me.widgets[i].elem = elem;
            if (me.widgets[i]['visible'] != nil and me.widgets[i].visible == 0) {
                elem.hide();
            }
        }


        me.cursor = me.guiOverlay.createChild("group");
        canvas.parsesvg(me.cursor, "Aircraft/E-jet-family/Models/Primus-Epic/cursor.svg", {'font-mapper': font_mapper});

        me.showFMSTarget = 1;

        me.selectUnderlay(nil);

        setlistener("/instrumentation/mfd[" ~ index ~ "]/lateral-range", func (node) {
            self.setRange(node.getValue());
        }, 1, 0);
        setlistener(me.props['heading-bug'], func (node) {
            self.elems['arc.heading-bug'].setRotation(node.getValue() * DC);
        }, 1, 0);
        setlistener(me.props['nav-src'], func (node) {
            self.updateNavSrc();
        }, 1, 0);
        setlistener(me.props['wp-id'], func (node) {
            self.updateNavSrc();
        }, 0, 0);
        setlistener("/autopilot/route-manager/active", func {
            self.updatePlanWPT();
        }, 1, 0);
        setlistener(me.props['page'], func (node) {
            self.updatePage();
        }, 1, 0);
        setlistener(me.props['cursor'], func (node) {
            self.cursor.setTranslation(
                self.props['cursor.x'].getValue(),
                self.props['cursor.y'].getValue()
            );
        }, 1, 2);
        setlistener(me.props['show-navaids'], func (node) {
            var viz = node.getBoolValue();
            self.elems['checkNavaids'].setVisible(viz);
            self.map.layers['NDB'].setVisible(viz);
            self.map.layers['VOR'].setVisible(viz);
        }, 1, 0);
        setlistener(me.props['show-airports'], func (node) {
            var viz = node.getBoolValue();
            var range = me.map.getRange();
            self.elems['checkAirports'].setVisible(viz);
            self.map.layers["RWY"].setVisible(range < 9.5 and viz);
            self.map.layers["APT"].setVisible(range >= 9.5 and range < 99.5 and viz);
        }, 1, 0);
        setlistener(me.props['show-wpt'], func (node) {
            var viz = node.getBoolValue();
            self.elems['checkWptIdent'].setVisible(viz);
            self.map.layers['WPT'].setVisible(viz);
        }, 1, 0);
        setlistener(me.props['show-progress'], func (node) {
            var viz = node.getBoolValue();
            self.elems['checkProgress'].setVisible(viz);
            self.elems['progress.master'].setVisible(viz);
        }, 1, 0);
        setlistener(me.props['show-missed'], func (node) {
            var viz = node.getBoolValue();
            self.elems['checkMissedAppr'].setVisible(viz);
            # TODO: toggle missed approach display
        }, 1, 0);
        setlistener(me.props['show-tcas'], func (node) {
            var viz = node.getBoolValue();
            self.elems['checkTCAS'].setVisible(viz);
            self.elems['tcas.master'].setVisible(viz);
            self.map.layers['TFC-Ejet'].setVisible(viz);
        }, 1, 0);
        setlistener(me.props['tcas-mode'], func (node) {
            var mode = node.getValue();
            if (mode == 3) {
                # TA/RA
                self.elems['tcas.mode'].setColor(0, 1, 0);
                self.elems['tcas.mode'].setText('TCAS TA/RA');
            }
            else if (mode == 2) {
                # TA ONLY
                self.elems['tcas.mode'].setColor(0, 1, 0);
                self.elems['tcas.mode'].setText('TA ONLY');
            }
            else {
                # TCAS OFF
                self.elems['tcas.mode'].setColor(1, 0.75, 0);
                self.elems['tcas.mode'].setText('TCAS OFF');
            }
        }, 1, 0);

        return me;
    },

    setRange: func(range) {
        var aptVisible = me.props['show-airports'].getBoolValue();
        me.map.setRange(range);
        me.plan.setRange(range);
        me.map.layers["TAXI"].setVisible(range < 9.5);
        me.map.layers["RWY"].setVisible(range < 9.5 and aptVisible);
        me.map.layers["APT"].setVisible(range >= 9.5 and range < 99.5 and aptVisible);
        var fmt = "%2.0f";
        if (range < 20)
            fmt = "%3.1f";
        var rangeTxt = sprintf(fmt, range / 2);
        me.elems['arc.range.left'].setText(rangeTxt);
        me.elems['arc.range.right'].setText(rangeTxt);
        me.elems['plan.range'].setText(rangeTxt);
    },


    touch: func(args) {
        var x = args.x * 1024;
        var y = 1560 - args.y * 1560;

        me.props['cursor.x'].setValue(x);
        me.props['cursor.y'].setValue(y);

        var activeCond = nil;
        forindex(var i; me.widgets) {
            if (me.widgets[i]['visible'] == 0) {
                continue;
            }
            activeCond = me.widgets[i]['active'];
            if (isfunc(activeCond) and !activeCond()) {
                continue;
            }
            var box = me.widgets[i].box;
            if (x >= box[0] and x <= box[2] and
                y >= box[1] and y <= box[3]) {
                var f = me.widgets[i].ontouch;
                if (f != nil) {
                    f();
                    break;
                }
            }
        }
    },

    # direction: -1 = decrease, 1 = increase
    # knob: 0 = outer ring, 1 = inner ring
    scroll: func(direction, knob=0) {
        var page = me.props['page'].getValue();
        if (page == 0) {
            # map mode
            if (knob == 0) {
                # range
                me.zoom(direction);
            }
        }
        else if (page == 1) {
            # plan mode
            if (knob == 0) {
                # range
                me.zoom(direction);
            }
            else {
                me.movePlanWpt(direction);
            }
        }
        else {
            # systems mode
        }
    },

    zoom: func (direction) {
        var range = me.props['range'].getValue();
        var ranges = [2, 5, 10, 20, 50, 100, 200, 500, 1000];
        var i = 0;
        forindex (var j; ranges) {
            if (range <= ranges[j]) {
                i = j;
                break;
            }
        }
        range = ranges[math.max(0, math.min(size(ranges)-1, i + direction))];
        me.props['range'].setValue(range);
    },

    updatePlanWPT: func () {
        var fp = fms.getVisibleFlightplan();
        var wp = nil;
        var (lat,lon) = geo.aircraft_position().latlon();

        if (fp == nil) {
            # No flightplan
            wp = nil;
        }
        else {
            wp = fp.getWP(me.planIndex)
        }
        if (wp != nil) {
            lat = wp.lat;
            lon = wp.lon;
        }
        me.plan.controller.setPosition(lat, lon);
    },

    movePlanWpt: func (direction) {
        var fp = fms.getVisibleFlightplan();
        me.planIndex += direction;
        if (me.planIndex < 0) {
            me.planIndex = 0;
        }
        if (fp == nil) {
            me.planIndex = 0;
        }
        else if (me.planIndex >= fp.getPlanSize()) {
            me.planIndex = fp.getPlanSize() - 1;
        }
        me.updatePlanWPT();
    },

    touchMap: func () {
        if (me.props['page'].getValue() == 0) {
            me.elems['mapMenu'].toggleVisibility();
        }
        else {
            me.props['page'].setValue(0);
        }
    },

    touchPlan: func () {
       me.props['page'].setValue(1);
    },

    touchSystems: func () {
       me.props['page'].setValue(2);
    },

    toggleMapCheckbox: func (which) {
        me.props['show-' ~ which].toggleBoolValue();
    },

    selectUnderlay: func (which) {
        me.elems['radioWeather'].setVisible(which == 'WX');
        me.elems['weather.master'].setVisible(which == 'WX');
        # WXR layer is buggy.
        # me.map.layers['WXR'].setVisible(which == 'WX');

        me.elems['radioTerrain'].setVisible(which == 'TERRAIN');
        me.elems['terrain.master'].setVisible(which == 'TERRAIN');
        # TERR layer not available in FGDATA as of 2020.2
        # me.map.layers['TERR'].setVisible(which == 'TERRAIN');

        me.elems['radioOff'].setVisible(which == nil);
    },

    updateNavSrc: func () {
        var navSrc = me.props['nav-src'].getValue();
        if (navSrc == 0) {
            var id = me.props['wp-id'].getValue();
            me.elems['nav.src'].setText('FMS' ~ (me.index + 1));
            me.elems['nav.src'].setColor(1, 0, 1);
            me.elems['nav.target.name'].setText(id);
            me.elems['nav.target.name'].setColor(1, 0, 1);
            me.elems['nav.target'].show();
            me.showFMSTarget = 1;
        }
        else {
            var lbl = 'VOR';
            if (me.props['nav-loc'][navSrc - 1].getValue()) {
                lbl = 'LOC';
            }
            var id = me.props['nav-id'][navSrc - 1].getValue();
            me.elems['nav.src'].setText(lbl ~ navSrc);
            me.elems['nav.src'].setColor(0, 1, 0);
            me.elems['nav.target.name'].setText(id);
            me.elems['nav.target.name'].setColor(0, 1, 0);
            me.elems['nav.target'].hide();
            me.showFMSTarget = 0;
        }
    },

    updatePage: func() {
        var page = me.props['page'].getValue();
        if (page == 0) {
            # Arc ("Map")
            me.elems['arc.master'].show();
            me.map.show();
            me.elems['plan.master'].hide();
            me.plan.hide();
        }
        else if (page == 1) {
            # Plan
            me.elems['arc.master'].hide();
            me.map.hide();
            me.elems['plan.master'].show();
            me.plan.show();
            me.elems['mapMenu'].hide();
        }
        else {
            # Systems
            me.elems['arc.master'].hide();
            me.map.hide();
            me.elems['plan.master'].hide();
            me.plan.hide();
            me.elems['mapMenu'].hide();
        }
    },

    update: func () {
        var heading = me.props['heading-mag'].getValue();
        var headingBug = me.props['heading-bug'].getValue();
        var headingDiff = geo.normdeg180(headingBug - heading);
        if (headingDiff < -90) {
            me.elems['arc.heading-bug'].hide();
            me.elems['arc.heading-bug.arrow-left'].show();
            me.elems['arc.heading-bug.arrow-right'].hide();
        }
        else if (headingDiff > 90) {
            me.elems['arc.heading-bug'].hide();
            me.elems['arc.heading-bug.arrow-left'].hide();
            me.elems['arc.heading-bug.arrow-right'].show();
        }
        else {
            me.elems['arc.heading-bug'].show();
            me.elems['arc.heading-bug.arrow-left'].hide();
            me.elems['arc.heading-bug.arrow-right'].hide();
        }
        me.elems['arc'].setRotation(heading * -DC);
        me.elems['heading.digital'].setText(sprintf("%03.0f", heading));
        me.elems['wind.arrow'].setRotation(me.props['wind-dir'].getValue() * DC);
        me.elems['wind.digital'].setText(sprintf("%2.0f", me.props['wind-speed'].getValue()));
        me.elems['tat.digital'].setText(sprintf("%3.0f", me.props['tat'].getValue()));
        me.elems['sat.digital'].setText(sprintf("%3.0f", me.props['sat'].getValue()));
        me.elems['tas.digital'].setText(sprintf("%3.0f", me.props['tas'].getValue()));
        if (me.showFMSTarget) {
            var dist = me.props['wp-dist'].getValue();
            me.elems['nav.target.dist'].setText(me.formatDist(dist));

            var ete = me.props['wp-ete'].getValue();
            var eteStr = '---';
            if (ete != nil) {
                eteStr = sprintf("%3.0f", ete / 60.0);
            }
            me.elems['nav.target.ete'].setText(eteStr);
        }
        if (me.props['route-active'].getValue()) {
            var now = me.props['zulutime'].getValue();

            me.elems['next.dist'].setText(me.formatDist(me.props['wp-dist'].getValue()));
            var wpETE = me.props['wp-ete'].getValue();
            if (wpETE != nil and wpETE > 86400) {
                me.elems['next.eta'].setText('+++++');
            }
            else {
                me.elems['next.eta'].setText(me.formatETA(now + (me.props['wp-ete'].getValue() or 0)));
            }
            me.elems['next.wpt'].setText(me.props['wp-id'].getValue() or '---');
            me.elems['next.fuel'].setText('---'); # TODO: fuel plan

            me.elems['dest.dist'].setText(me.formatDist(me.props['dest-dist'].getValue()));
            var destETE = me.props['dest-ete'].getValue();
            if (destETE != nil and destETE > 86400) {
                me.elems['dest.eta'].setText('+++++');
            }
            else {
                me.elems['dest.eta'].setText(me.formatETA(now + (me.props['dest-ete'].getValue() or 0)));
            }
            me.elems['dest.wpt'].setText(me.props['dest-id'].getValue() or '---');
            me.elems['dest.fuel'].setText('---'); # TODO: fuel plan
        }
        me.map.layers['TFC-Ejet'].update();
    },

    formatDist: func(dist) {
        var distStr = '----';
        if (dist != nil) {
            var distFmt = "%4.1f";
            if (dist >= 50.0) {
                distFmt = "%4.0f";
            }
            distStr = sprintf(distFmt, dist);
        }
        return distStr;
    },

    formatETA: func(time_secs) {
        var corrected = math.mod(time_secs, 86400);
        var hours = math.floor(corrected / 3600);
        var minutes = math.mod(math.floor(corrected / 60), 60);
        return sprintf("%02.0fH%02.0f", hours, minutes);
    },
};

var path = resolvepath('Aircraft/E-jet-family/Models/Primus-Epic/MFD');
canvas.MapStructure.loadFile(path ~ '/TFC-Ejet.lcontroller', 'TFC-Ejet');
canvas.MapStructure.loadFile(path ~ '/TFC-Ejet.symbol', 'TFC-Ejet');

setlistener("sim/signals/fdm-initialized", func {
    for (var i = 0; i <= 1; i += 1) {
        mfd_display[i] = canvas.new({
            "name": "MFD" ~ i,
            "size": [1024, 1560],
            "view": [1024, 1560],
            "mipmapping": 1
        });
        mfd_display[i].addPlacement({"node": "MFD" ~ i});
        mfd[i] =
            MFD.new(
                mfd_display[i].createGroup(),
                "Aircraft/E-jet-family/Models/Primus-Epic/MFD.svg",
                i);
    }

    var timer = maketimer(0.1, func() {
        mfd[0].update();
        mfd[1].update();
    });
    timer.start();
});
