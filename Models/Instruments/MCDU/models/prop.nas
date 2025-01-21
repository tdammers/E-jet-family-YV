# Model backed by a property
var PropModel = {
    new: func (prop, key = nil, defval = '', format = nil) {
        var m = BaseModel.new();
        m.parents = prepended(PropModel, m.parents);
        m.key = key;
        m.format = format;
        m.prop = (typeof(prop) == 'scalar') ?
                    props.globals.getNode(prop) :
                    prop;
        if (defval == nil) {
            m.defval = '';
        }
        else {
            m.defval = defval;
        }
        return m;
    },

    getKey: func () {
        return me.key;
    },

    get: func () {
        if (me.prop != nil) {
            var val = me.prop.getValue();
            if (val == nil)
                return nil;
            if (typeof(me.format) == 'func')
                return me.format(val);
            elsif (typeof(me.format) == 'scalar')
                return sprintf(me.format, val);
            else
                return val;
        }
        else {
            return nil;
        }
    },

    set: func (val) {
        if (me.prop != nil) {
            me.prop.setValue(val);
        }
    },

    reset: func () {
        var val = me.defval;
        if (typeof(me.defval) == 'func') {
            val = me.defval();
        }
        me.set(val);
    },

    subscribe: func (f) {
        if (me.prop != nil) {
            return setlistener(me.prop, func () {
                var val = me.prop.getValue();
                f(val);
            });
        }
    },

    unsubscribe: func (l) {
        removelistener(l);
    },
};

