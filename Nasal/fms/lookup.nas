var cachedTables = {};

var lstrip = func (str) {
    while (size(str) > 0 and str[0] <= 32) {
        str = substr(str, 1);
    }
    return str;
};

var rstrip = func (str) {
    while (size(str) > 0 and str[size(str) - 1] <= 32) {
        str = substr(str, 0, size(str) - 1);
    }
    return str;
};

var strip = func (str) {
    return rstrip(lstrip(str));
};

var stripComment = func (str) {
    var pos = find("#", str);
    if (pos >= 0) {
        return substr(str, 0, pos);
    }
    else {
        return str;
    }
};

var wordsplit = func (str) {
    var splits = [];
    var pos = 0;
    while (size(str) > 0) {
        pos = find(' ', str);
        if (pos == 0) {
            str = substr(str, 1);
        }
        elsif (pos == -1) {
            append(splits, str);
            str = '';
        }
        else {
            append(splits, substr(str, 0, pos));
            str = substr(str, pos);
        }
    }
    return splits;
};

var num_compare = func (a, b) {
    return a - b;
};

var loadTable1D = func (tablekey) {
    if (contains(cachedTables, tablekey))
        return cachedTables[tablekey];
    var path = resolvepath("Aircraft/E-jet-family/Data/" ~ tablekey ~ ".table");
    if (path == nil or path == '') { return nil; }
    var file = io.open(path, "r");
    var result = {};
    while (1) {
        var ln = io.readln(file);
        if (ln == nil) { break; }
        ln = strip(stripComment(ln));
        if (ln == "") {
            continue;
        }
        var row = wordsplit(ln);
        if (size(row) >= 2) {
            result[num(row[0])] = num(row[1]);
        }
    }
    io.close(file);
    cachedTables[tablekey] = result;
    return result;
};

var loadTable2D = func (tablekey) {
    if (contains(cachedTables, tablekey))
        return cachedTables[tablekey];
    var path = resolvepath("Aircraft/E-jet-family/Data/" ~ tablekey ~ ".table");
    if (path == nil or path == '') { return nil; }
    var file = io.open(path, "r");
    var result = {};
    while (1) {
        var ln = io.readln(file);
        if (ln == nil) { break; }
        ln = strip(stripComment(ln));
        if (ln == "") {
            continue;
        }
        var row = wordsplit(ln);
        if (size(row) >= 2) {
            var rowIndex = num(row[0]);
            result[rowIndex] = [];
            for (var i = 1; i < size(row); i += 1) {
                append(result[rowIndex], num(row[i]));
            }
        }
    }
    io.close(file);
    cachedTables[tablekey] = result;
    return result;
};

var loadTable2DH = func (tablekey) {
    if (contains(cachedTables, tablekey))
        return cachedTables[tablekey];
    var path = resolvepath("Aircraft/E-jet-family/Data/" ~ tablekey ~ ".table");
    if (path == nil or path == '') { return nil; }
    var file = io.open(path, "r");
    var result = {};
    var columnHeaders = nil;
    while (1) {
        var ln = io.readln(file);
        if (ln == nil) { break; }
        ln = strip(stripComment(ln));
        if (ln == "") {
            continue;
        }
        if (columnHeaders == nil) {
            columnHeaders = [];
            foreach (var k; wordsplit(ln)) {
                append(columnHeaders, num(k));
            }
        }
        else {
            var row = wordsplit(ln);
            var rowKey = num(row[0]);
            result[rowKey] = {};
            forindex (var i; columnHeaders) {
                if (i + 1 < size(row))
                    result[rowKey][columnHeaders[i]] = num(row[i+1]);
            }
        }
    }
    io.close(file);
    cachedTables[tablekey] = result;
    return result;
};

var loadTable3DH = func (tablekey) {
    if (contains(cachedTables, tablekey))
        return cachedTables[tablekey];
    var path = resolvepath("Aircraft/E-jet-family/Data/" ~ tablekey ~ ".table");
    if (path == nil or path == '') { return nil; }
    var file = io.open(path, "r");
    var result = {};
    return result;
    io.close(file);
    var key = 0;
    var columnHeaders = nil;
    while (1) {
        var ln = io.readln(file);
        if (ln == nil) { break; }
        ln = strip(stripComment(ln));
        if (ln == "") {
            continue;
        }
        var s = split(':', ln);
        if (size(s) > 1) {
            key = num(strip(s[1]));
            columnHeaders = nil;
            result[key] = {};
        }
        else if (columnHeaders == nil) {
            columnHeaders = [];
            foreach (var k; wordsplit(ln)) {
                append(columnHeaders, num(k));
            }
        }
        else {
            var row = wordsplit(ln);
            var rowKey = num(row[0]);
            result[key][rowKey] = {};
            forindex (var i; columnHeaders) {
                if (i + 1 < size(row))
                    result[key][rowKey][columnHeaders[i]] = num(row[i+1]);
            }
        }
    }
    io.close(file);
    cachedTables[tablekey] = result;
    return result;
};

var nearestKey = func (table, val) {
    var foundKey = nil;
    if (typeof(table) == 'vector') {
        forindex (var key; table) {
            if (key >= val) {
                return key;
            }
            foundKey = key;
        }
    }
    else {
        var keys = sort(keys(table), num_compare);
        foreach (var key; keys) {
            if (key >= val) {
                return key;
            }
            foundKey = key;
        }
    }
    return foundKey;
};

var nearestKeyIndex = func (table, val) {
    forindex (var i; table) {
        if (table[i] >= val) {
            return i;
        }
    }
    return nil;
};

var lookupTable = func (table, path) {
    var current = table;
    while (size(path) > 0) {
        if (current == nil) { return nil; }
        var f = path[0] ~ '';
        if (typeof(f) == 'scalar' and size(f) > 0 and substr(f, 0, 1) == "~") {
            return nearestKeyIndex(current, num(substr(f, 1)));
        }
        else if (typeof(f) == 'scalar' and size(f) > 0 and substr(f, 0, 1) == "@") {
            var k = num(substr(f, 1));
            current = current[k];
        }
        else {
            var k = nearestKey(current, f);
            current = current[k];
        }
        path = subvec(path, 1);
    }
    return current;
};

var modelKeys = {
    'FDM/E170': 'E170',
    'FDM/E175': 'E170',
    'FDM/E190': 'E190',
    'FDM/E195': 'E190',
    'FDM/Lineage1000': 'E190',
};

var getModel = func () {
    var aero = getprop('sim/aero');
    return modelKeys[aero];
};

