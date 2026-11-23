pragma Singleton

import QtQuick
import Quickshell

Singleton {
    property var _regexCache: ({})

    function isRegex(s: string): bool {
        return /^\^.*\$$/.test(s);
    }

    function getRegex(pattern: string): var {
        let re = _regexCache[pattern];
        if (re === undefined) {
            try {
                re = new RegExp(pattern);
            } catch (e) {
                console.warn("Strings.getRegex: Invalid regular expression pattern:", pattern, e);
                re = null;
            }
            _regexCache[pattern] = re;
        }
        return re;
    }

    function testRegex(pattern: string, target: string): bool {
        if (!pattern || !target)
            return false;
        if (isRegex(pattern)) {
            const re = getRegex(pattern);
            return re ? re.test(target) : pattern === target;
        }
        return pattern === target;
    }

    function testRegexList(filterList: var, target: string): bool {
        if (!filterList || !target)
            return false;
        const arr = Array.from(filterList);
        for (let i = 0; i < arr.length; i++) {
            const filter = arr[i];
            if (isRegex(filter)) {
                const re = getRegex(filter);
                if (re && re.test(target))
                    return true;
            } else if (filter === target) {
                return true;
            }
        }
        return false;
    }

    function findMatchingIndex(filterList: var, target: string): int {
        if (!filterList || !target)
            return -1;
        const arr = Array.from(filterList);
        for (let i = 0; i < arr.length; i++) {
            const filter = arr[i];
            if (isRegex(filter)) {
                const re = getRegex(filter);
                if (re && re.test(target))
                    return i;
            } else if (filter === target) {
                return i;
            }
        }
        return -1;
    }

    function percent(val: var): string {
        return `${Math.round(val ?? 0)}%`;
    }
}
