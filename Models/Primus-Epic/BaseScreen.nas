var BaseScreen = {

    # Args:
    # - canvas_group: the root canvas group to bind to.
    # - side: 0 = captain side, 1 = fo side, -1 = both.
    #         Determines which CCD(s) to listen to, and can also be used to
    #         map registered properties to the corresponding cockpit side
    #         (e.g. radios)
    # - ccdIndex: which CCD screen selector key to grab: 0 = left screen,
    #             1 = middle screen, 2 = right screen, -1 no CCD support.
    new: func(side=0, ccdIndex=-1) {
        var m = {
                parents: [BaseScreen],
                side: side,
                ccdIndex: ccdIndex,
                ccdCursorTimeout: 0,
                active: 0,
                ccds: [],
            };
        return m;
    },

    ############### Initialization hooks. ############### 

    # Override to register additional properties.
    registerProps: func () {
        var sides = [me.side];
        if (me.side < 0) {
            sides = [0, 1];
        }

        foreach (var side; sides) {
            append(me.ccds, {
                    'hasCursor': false,
                    'props': {
                        'ccd.rel-x': props.globals.getNode('controls/ccd[' ~ side ~ ']/rel-x'),
                        'ccd.rel-y': props.globals.getNode('controls/ccd[' ~ side ~ ']/rel-y'),
                        'ccd.rel-inner': props.globals.getNode('controls/ccd[' ~ side ~ ']/rel-inner'),
                        'ccd.rel-outer': props.globals.getNode('controls/ccd[' ~ side ~ ']/rel-outer'),
                        'ccd.screen-select': props.globals.getNode('controls/ccd[' ~ side ~ ']/screen-select'),
                        'ccd.click': props.globals.getNode('controls/ccd[' ~ side ~ ']/click'),
                    }
                });
        }

        me.registerProp('keyboard.shift', 'devices/status/keyboard/shift');
    },

    # Override to register additional elements. Use registerElemsFrom(), or add
    # dynamic elements to me.elems manually.
    registerElems: func () {
    },


    font_mapper: func(family, weight) {
        return "LiberationFonts/LiberationSans-Regular.ttf";
    },

    makeMasterGroup: func (group) {
    },

    # Override to create any canvas groups you may need. An empty me.guiOverlay
    # group is created by default; you can load an SVG into it, or fill it
    # dynamically, but it needs to exist because the CCD cursor will also go
    # into it.
    makeGroups: func () {
        me.guiOverlay = me.master.createChild("group");
    },

    # Override to add GUI widgets.
    makeWidgets: func () {
    },

    registerCCDListeners: func (i) {
        var self = me;
        var ccd = me.ccds[i];
        me.addListener('main', ccd.props['ccd.screen-select'], func (node) {
            var activeScreen = node.getValue();
            if (activeScreen == self.ccdIndex) {
                # Acquire CCD focus
                self.addListener('ccd' ~ i, ccd.props['ccd.rel-x'], func(node) {
                    var delta = node.getDoubleValue();
                    var p = self.props['cursor.x'];
                    p.setValue(math.min(1024, math.max(0, p.getValue() + delta)));
                    self.wakeupCursor();
                }, 0, 1, 1);
                self.addListener('ccd' ~ i, ccd.props['ccd.rel-y'], func (node) {
                    var delta = node.getDoubleValue();
                    var p = self.props['cursor.y'];
                    p.setValue(math.min(1366, math.max(0, p.getValue() + delta)));
                    self.wakeupCursor();
                }, 0, 1, 1);
                self.addListener('ccd' ~ i, ccd.props['ccd.click'], func(node) {
                    if (node.getBoolValue()) {
                        self.click();
                        self.wakeupCursor();
                    }
                }, 0, 1, 1);
                self.addListener('ccd' ~ i, ccd.props['ccd.rel-outer'], func(node) {
                    self.scroll(node.getValue(), 0);
                }, 0, 1, 1);
                self.addListener('ccd' ~ i, ccd.props['ccd.rel-inner'], func(node) {
                    self.scroll(node.getValue(), 1);
                }, 0, 1, 1);
                # Place cursor at center of screen, unless already visible
                if (!self.props["cursor.visible"].getBoolValue()) {
                    self.props["cursor.x"].setValue(512);
                    self.props["cursor.y"].setValue(683);
                }
                self.props["cursor.visible"].setBoolValue(1);
                self.wakeupCursor();
                ccd.hasCursor = 1;
            }
            else {
                # Release CCD focus
                self.clearListeners('ccd' ~ i);
                ccd.hasCursor = 0;
                var cursorVisible = 0;
                foreach (var ccd2; self.ccds) {
                    if (ccd2.hasCursor) {
                        cursorVisible = 1;
                        break;
                    }
                }
                if (!cursorVisible) {
                    self.props["cursor.visible"].setBoolValue(0);
                    self.ccdCursorTimeout = 0.0;
                }
            }
        }, 1, 0, 1);
    },

    # Override to register additional listeners.
    registerListeners: func () {
        var self = me;
        for (var i = 0; i < size(me.ccds); i += 1) {
            me.registerCCDListeners(i);
        }
        me.addListener('main', '@cursor.x', func (node) {
            self.cursor.setTranslation(
                self.props['cursor.x'].getValue(),
                self.props['cursor.y'].getValue()
            );
        }, 1, 0, 1);
        me.addListener('main', '@cursor.y', func (node) {
            self.cursor.setTranslation(
                self.props['cursor.x'].getValue(),
                self.props['cursor.y'].getValue()
            );
        }, 1, 0, 1);
        me.addListener('main', '@cursor.visible', func (node) {
            self.cursor.setVisible(node.getBoolValue());
        }, 1, 0);
    },

    ############### Interaction hooks ############### 

    # Override to handle scroll events that weren't accepted by any widgets.
    masterScroll: func (direction, knob=0) {},

    # Override to handle click events that weren't accepted by any widgets.
    masterClick: func (x, y) {},

    ############### Update hooks ############### 

    # Low-frequency updates (on the order of 1 Hz)
    updateSlow: func (dt) {
    },

    # High-frequency updates (at frame rate or similar)
    update: func (dt) {
        if (me.ccdCursorTimeout > 0) {
            me.ccdCursorTimeout -= dt;
            if (!(me.ccdCursorTimeout > 0.0)) {
                me.props['cursor.visible'].setBoolValue(0);
            }
        }
        me.runListeners();
    },

    ############### Lifecycle hooks ############### 
    postInit: func () {},
    preActivate: func () {},
    postActivate: func () {},
    preDeactivate: func () {},
    postDeactivate: func () {},
    postDeinit: func () {},

    ############### Listeners. Do not override. ############### 

    addListenerGroup: func (name) {
        if (!contains(me.listeners, name)) {
            me.listeners[name] = [];
        }
    },

    clearListeners: func (group=nil) {
        if (group == nil) {
            foreach (var name; keys(me.listeners))
                me.clearListeners(name);
        }
        else {
            if (contains(me.listeners, group)) {
                foreach (var l; me.listeners[group]) {
                    removelistener(l.lid);
                }
                me.listeners[group] = [];
            }
        }
    },

    addListener: func (group, prop, fn, init=0, type=1, immediate=0) {
        me.addListenerGroup(group);
        if (typeof(prop) == 'scalar') {
            if (substr(prop, 0, 1) == '@') {
                prop = me.props[substr(prop, 1)];
            }
            else {
                prop = props.globals.getNode(prop);
            }
        }
        var listener = {
            value: nil,
            node: prop,
            dirty: 0,
            fn: fn,
            immediate: immediate,
        };
        var deferFn = func (node) { listener.dirty = 1; };
        listener.lid = setlistener(prop, immediate ? fn : deferFn, init, type);
        append(me.listeners[group], listener);
    },

    runListeners: func (group=nil) {
        if (group == nil) {
            foreach (var name; keys(me.listeners))
                me.runListeners(name);
        }
        else {
            if (contains(me.listeners, group)) {
                foreach (var l; me.listeners[group]) {
                    if (l.dirty) {
                        l.fn(l.node);
                        l.dirty = 0;
                    }
                }
            }
        }
    },

    ############### Registered properties. Do not override. ############### 

    # Register a property under a given key.
    # pathOrNode may be one of:
    # - a string, representing a property path
    # - a Node
    # - a vector, where each element is either a string or a Node.
    registerProp: func (key, pathOrNode=nil, create=0) {
        if (pathOrNode == nil) pathOrNode = key;
        if (typeof(pathOrNode) == 'vector') {
            items = [];
            foreach (var k; pathOrNode) {
                if (typeof(k) == 'scalar') {
                    append(items, props.globals.getNode(k, 1));
                }
                else {
                    append(items, k);
                }
            }
            me.props[key] = items;
        }
        elsif (typeof(pathOrNode) == 'scalar') {
            me.props[key] = props.globals.getNode(pathOrNode, 1);
        }
        else {
            me.props[key] = pathOrNode;
        }
    },

    ############### Widgets. Do not override. ############### 

    addWidget: func (key, options, group=nil) {
        var widget = { key: key };
        if (group == nil) group = me.guiOverlay;
        if (contains(options, 'active')) widget.active = options.active;
        if (contains(options, 'onclick')) widget.onclick = options.onclick;
        if (contains(options, 'onscroll')) widget.onscroll = options.onscroll;

        var elem = group.getElementById(widget.key);
        if (elem == nil)
            elem = me.elems[widget.key];
        var boxElem = group.getElementById(widget.key ~ ".clickbox");
        if (boxElem == nil) {
            widget.boxElem = elem;
        }
        else {
            widget.boxElem = boxElem;
        }
        widget.elem = elem;
        if (widget['visible'] != nil and widget.visible == 0) {
            elem.hide();
        }

        append(me.widgets, widget);
    },

    ############### Registered elements. Do not override. ############### 

    registerElemsFrom: func (elemKeys, group=nil) {
        if (group == nil) group = me.master;
        foreach (var key; elemKeys) {
            me.elems[key] = group.getElementById(key);
            if (me.elems[key] == nil) {
                debug.warn("Element does not exist: " ~ key);
                continue;
            }

            var clip_el = me.master.getElementById(key ~ "_clip");
            if (clip_el != nil) {
                clip_el.setVisible(0);
                var tran_rect = clip_el.getTransformedBounds();
                var clip_rect = sprintf("rect(%d,%d, %d,%d)",
                tran_rect[1], # 0 ys
                tran_rect[2], # 1 xe
                tran_rect[3], # 2 ye
                tran_rect[0]); #3 xs
                #   coordinates are top,right,bottom,left (ys, xe, ye, xs) ref: l621 of simgear/canvas/CanvasElement.cxx
                me.elems[key].set("clip", clip_rect);
                me.elems[key].set("clip-frame", canvas.Element.PARENT);
            }
        }
    },

    registerElem: func (key, elem, group=nil) {
        if (group == nil) group = me.master;
        if (typeof(elem) == 'func')
            elem = elem(group);
        if (typeof(elem) == 'scalar')
            elem = group.getElementById(key);
        if (elem == nil) {
            debug.warn("Element does not exist: " ~ key);
        }
        else {
            me.elems[key] = elem;
        }
        return elem;
    },

    ############### Input handling. Do not override. ############### 

    touch: func(args) {
        var x = args.x * 1024;
        var y = 1560 - args.y * 1560;

        me.ccds[0].props['ccd.screen-select'].setValue(me.ccdIndex);
        me.props['cursor.x'].setValue(x);
        me.props['cursor.x'].setValue(x);
        me.props['cursor.y'].setValue(y);
        me.props['cursor.y'].setValue(y);

        if (me.props['keyboard.shift'].getBoolValue()) {
            # only touch, no click
        }
        else {
            me.click(x, y);
        }
    },

    click: func(x=nil, y=nil) {
        if (x == nil) x = me.props['cursor.x'].getValue();
        if (y == nil) y = me.props['cursor.y'].getValue();
        var activeCond = nil;
        foreach (var widget; me.widgets) {
            if (widget['visible'] == 0) {
                continue;
            }
            activeCond = widget['active'];
            if (isfunc(activeCond) and !activeCond()) {
                continue;
            }
            var box = widget.boxElem.getTransformedBounds();
            if (x >= box[0] and x <= box[2] and
                y >= box[1] and y <= box[3]) {
                var f = widget['onclick'];
                if (f != nil) {
                    f();
                    return;
                }
            }
        }
        me.masterClick(x, y);
    },

    # direction: -1 = decrease, 1 = increase
    # knob: 0 = outer ring, 1 = inner ring
    scroll: func(direction, knob=0, x=nil, y=nil) {
        if (x == nil) x = me.props['cursor.x'].getValue();
        if (y == nil) y = me.props['cursor.y'].getValue();
        var activeCond = nil;
        foreach (var widget; me.widgets) {
            if (widget['visible'] == 0) {
                continue;
            }
            activeCond = widget['active'];
            if (isfunc(activeCond) and !activeCond()) {
                continue;
            }
            var box = widget.boxElem.getTransformedBounds();
            if (x >= box[0] and x <= box[2] and
                y >= box[1] and y <= box[3]) {
                var f = widget['onscroll'];
                if (f != nil) {
                    f(direction, knob);
                    return;
                }
            }
        }
        # No widget wants this event; process as master scroll.
        me.masterScroll(direction, knob);
    },

    wakeupCursor: func () {
        me.ccdCursorTimeout = 10.0;
        me.props['cursor.visible'].setValue(1);
    },


    ############### Lifecycle management. Do not override. ############### 

    activate: func () {
        if (me.active) return;
        me.preActivate();
        me.registerListeners();
        me.postActivate();
        me.active = 1;
    },

    deactivate: func () {
        if (!me.active) return;
        me.preDeactivate();
        me.clearListeners();
        me.postDeactivate();
        me.active = 0;
    },

    init: func (canvas_group) {
        var self = me; # for listeners

        me.listeners = {};
        me.listeners.ccd = [];
        me.listeners.main = [];
        me.elems = {};
        me.props = {};
        me.widgets = [];

        me.registerProps();
        me.master = canvas_group;
        me.makeMasterGroup(canvas_group);
        me.makeGroups();
        me.registerElems();
        me.makeWidgets();
        me.cursor = me.guiOverlay.createChild("group");
        if (me.ccdIndex >= 0)
            canvas.parsesvg(me.cursor, "Aircraft/E-jet-family/Models/Primus-Epic/cursor.svg", {'font-mapper': me.font_mapper});

        me.postInit();

        return me;
    },

    deinit: func {
        me.deactivate();
        me.postDeinit();
    },

};

