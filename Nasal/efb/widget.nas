include('util.nas');

var Widget = {
    new: func (where=nil) {
        return {
            parents: [Widget],
            where: where,
            what: nil,
            children: [],
            active: 1,
            options: {
            }
        }
    },

    setOption: func (key, val) {
        me.options[key] = val;
        return me;
    },

    setHandler: func (what) {
        me.what = what;
        return me;
    },

    setActive: func (active) {
        me.active = active;
        return me;
    },

    appendChild: func (child) {
        append(me.children, child);
        return me;
    },

    removeAllChildren: func () {
        me.children = [];
        return me;
    },

    checkTouch: func (x, y) {
        if (!me.active)
            return 0;
        var where = me.where;
        var xy = [x, y];
        if (typeof(where) == 'nil')
            return 0;
        if (typeof(where) == 'hash' and contains(where, 'parents')) {
            # This is probably a canvas element, or so we hope...
            xy = where.canvasToLocal(xy);
            where = where.getTightBoundingBox();
        }
        if ((xy[0] >= where[0]) and
            (xy[0] < where[2]) and
            (xy[1] >= where[1]) and
            (xy[1] < where[3])) {
            return [xy[0] - where[0], xy[1] - where[1], where[2] - where[0], where[3] - where[1]];
        }
        else {
            return nil;
        }
    },

    touch: func (x, y) {
        if (!me.active)
            return 1; # keep going
        foreach (var child; me.children) {
            # If child handles event, stop.
            if (!child.touch(x, y))
                return 0;
        }
        var touchCoords = me.checkTouch(x, y);
        if (touchCoords != nil) {
            if (me.what == nil) {
                # We don't have a handler of our own; bubble.
                return 1;
            }
            else {
                return me.what(touchCoords) or 0;
            }
        }
        else {
            return 1;
        }
    },

};
