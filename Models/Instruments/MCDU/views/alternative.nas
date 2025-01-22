var AlternativeView = {
    new: func (x, y, flags, w, alternatives) {
        var m = BaseView.new(x, y, flags);
        m.parents = prepended(AlternativeView, m.parents);
        m.alternatives = alternatives;
        for (var i = 0; i < size(m.alternatives); i += 1) {
            if (typeof(m.alternatives[i].model) == "scalar") {
                m.alternatives[i].model = modelFactory(m.alternatives[i].model);
            }
        }
        m.listeners = [];
        return m;
    },

    getKey: func () {
        if (me.alternatives == nil or size(me.alternatives) == 0) return nil;
        return me.alternatives[0].model.getKey();
    },

    drawAuto: func (mcdu) {
        var val = nil;
        var cond = nil;
        var go = 0;
        foreach (var branch; me.alternatives) {
            val = branch.model.get();
            if (!contains(branch, 'cond')) {
                go = 1;
            }
            elsif (branch.cond == nil) {
                go = 1;
            }
            elsif (typeof(branch.cond) == 'func') {
                go = branch.cond(val);
            }
            elsif (typeof(branch.cond) == 'scalar') {
                go = (val == branch.cond);
            }
            elsif (typeof(branch.cond) == 'hash') {
                go = contains(branch.cond, val) and branch.cond[val];
            }
            else {
                die("Invalid branch.cond");
            }
            if (go) {
                me.drawBranch(mcdu, branch, val);
                return;
            }
        }
    },

    drawBranch: func (mcdu, branch, val) {
        debug.dump(branch, val);
        var flags = me.flags;
        var draw = contains(branch, 'draw') ? branch.draw : nil;
        if (contains(branch, 'flags')) {
            flags = branch.flags;
        }
        if (typeof(draw) == 'func') {
            draw(mcdu, me.x, me.y, flags, val);
        }
        elsif (typeof(draw) == 'scalar') {
            mcdu.print(me.x, me.y, sprintf(format, val), flags);
        }
        elsif (draw == nil) {
            mcdu.print(me.x, me.y, sprintf('%' ~ me.w ~ 's', val), flags);
        }
    },


    activate: func (mcdu) {
        var self = me;
        foreach (var branch; me.alternatives) {
            (func () {
                var listener = branch.model.subscribe(func (val) {
                    self.drawAuto(mcdu);
                });
                if (listener != nil) {
                    append(self.listeners, [branch.model, listener]);
                }
            })();
        }
    },

    deactivate: func () {
        foreach (listener; me.listeners) {
            listener[0].unsubscribe(listener[1]);
        }
        me.listeners = [];
    },
};
