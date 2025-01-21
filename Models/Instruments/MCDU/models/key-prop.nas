# Prop model that is linked to a prop key, allowing it to be boxed.
var KeyPropModel = {
    new: func (key, defval = nil) {
        var keyProp = keyProps[key];
        var pkey = keyProp;
        var format = nil;
        if (typeof(keyProp) == 'vector') {
            pkey = keyProp[0];
            format = keyProp[1];
        }
        prop = props.globals.getNode(pkey, 1);
        if (defval == nil) {
            defval = keyDefs[key];
        }
        var m = PropModel.new(prop, key, defval, format);
        m.parents = prepended(KeyPropModel, m.parents);
        m.key = key;
        return m;
    },
};


