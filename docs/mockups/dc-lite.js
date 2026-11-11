// SPDX-License-Identifier: GPL-3.0-or-later
//
// Tiny runtime for the Kamerton design mockups in this folder.
//
// The mockups were drawn as "Design Component" pages: an <x-dc> template with
// {{holes}}, <sc-if>, <sc-for> and on* handlers, plus a
// <script type="text/x-dc"> holding `class Component extends DCLogic`.
// This file implements just that subset so the pages run from disk in any browser.
//
// Props come from the data-props defaults and can be overridden with URL
// parameters, e.g. v3-refined.html?layout=c2&theme=light&startInstrument=violin

(function () {
    'use strict';

    class DCLogic {
        constructor(props) {
            this.props = props;
            this.state = null;
            this._callbacks = [];
            this._queued = false;
        }

        setState(update, callback) {
            const patch = typeof update === 'function' ? update(this.state || {}, this.props) : update;
            this.state = Object.assign({}, this.state || {}, patch);
            if (callback) {
                this._callbacks.push(callback);
            }
            this._schedule();
        }

        forceUpdate(callback) {
            if (callback) {
                this._callbacks.push(callback);
            }
            this._schedule();
        }

        _schedule() {
            if (this._queued) {
                return;
            }
            this._queued = true;
            queueMicrotask(() => {
                this._queued = false;
                this._render();
                const callbacks = this._callbacks;
                this._callbacks = [];
                callbacks.forEach((f) => f());
            });
        }
    }
    window.DCLogic = DCLogic;

    const HOLE = /\{\{\s*([^}]+?)\s*\}\}/g;
    const WHOLE = /^\s*\{\{\s*([^}]+?)\s*\}\}\s*$/;
    const BOOLEAN_ATTRS = new Set(['checked', 'disabled', 'selected', 'hidden', 'readonly']);

    function lookup(path, scope) {
        if (path === 'true') return true;
        if (path === 'false') return false;
        if (path === 'null') return null;
        if (/^-?\d+(\.\d+)?$/.test(path)) return Number(path);
        let value = scope;
        for (const part of path.split('.')) {
            if (value == null) return undefined;
            value = value[part];
        }
        return value;
    }

    function interpolate(text, scope) {
        return text.replace(HOLE, (_, path) => {
            const v = lookup(path, scope);
            return v == null ? '' : String(v);
        });
    }

    // Template node -> fresh DOM nodes for the current values.
    function build(node, scope, out) {
        if (node.nodeType === Node.TEXT_NODE) {
            const text = node.nodeValue.includes('{{') ? interpolate(node.nodeValue, scope) : node.nodeValue;
            out.push(document.createTextNode(text));
            return;
        }
        if (node.nodeType !== Node.ELEMENT_NODE) {
            return;
        }

        const tag = node.localName;
        if (tag === 'sc-if') {
            const m = WHOLE.exec(node.getAttribute('value') || '');
            if (m && lookup(m[1], scope)) {
                node.childNodes.forEach((c) => build(c, scope, out));
            }
            return;
        }
        if (tag === 'sc-for') {
            const m = WHOLE.exec(node.getAttribute('list') || '');
            const list = (m && lookup(m[1], scope)) || [];
            const as = node.getAttribute('as') || 'item';
            list.forEach((item, index) => {
                const inner = Object.create(scope);
                inner[as] = item;
                inner.$index = index;
                node.childNodes.forEach((c) => build(c, inner, out));
            });
            return;
        }

        const el = document.createElementNS(node.namespaceURI, tag);
        el.__on = {};
        for (const attr of node.attributes) {
            const name = attr.name;
            if (name.startsWith('hint-')) {
                continue;
            }
            const whole = WHOLE.exec(attr.value);
            if (name.startsWith('on') && whole) {
                el.__on[name.slice(2)] = lookup(whole[1], scope);
            } else if (whole) {
                const v = lookup(whole[1], scope);
                if (BOOLEAN_ATTRS.has(name)) {
                    if (v) el.setAttribute(name, '');
                } else if (v != null && (v !== false || name.startsWith('aria-'))) {
                    el.setAttribute(name, String(v));
                }
            } else {
                el.setAttribute(name, attr.value.includes('{{') ? interpolate(attr.value, scope) : attr.value);
            }
        }
        // React-style onChange fires while a slider or text field is edited.
        if (el.__on.change && el.localName === 'input' && el.getAttribute('type') !== 'checkbox') {
            el.__on.input = el.__on.change;
            delete el.__on.change;
        }

        const children = [];
        node.childNodes.forEach((c) => build(c, scope, children));
        children.forEach((c) => el.appendChild(c));
        out.push(el);
    }

    // Every element gets one dispatcher per event type; handlers are swapped on each render.
    function bind(el) {
        if (el.nodeType !== Node.ELEMENT_NODE) {
            return;
        }
        el.__bound = el.__bound || {};
        for (const type of Object.keys(el.__on || {})) {
            if (!el.__bound[type]) {
                el.__bound[type] = true;
                el.addEventListener(type, (e) => {
                    const handler = el.__on && el.__on[type];
                    if (typeof handler === 'function') handler(e);
                });
            }
        }
        el.childNodes.forEach(bind);
    }

    // Patch the live DOM to match freshly built nodes, keeping focus and slider drags intact.
    function morphChildren(parent, fresh) {
        const old = Array.from(parent.childNodes);
        fresh.forEach((n, i) => {
            const o = old[i];
            if (!o) {
                parent.appendChild(n);
                bind(n);
            } else if (o.nodeType !== n.nodeType || o.nodeName !== n.nodeName || o.namespaceURI !== n.namespaceURI) {
                parent.replaceChild(n, o);
                bind(n);
            } else if (o.nodeType === Node.TEXT_NODE) {
                if (o.nodeValue !== n.nodeValue) o.nodeValue = n.nodeValue;
            } else {
                morphElement(o, n);
            }
        });
        for (let i = fresh.length; i < old.length; ++i) {
            parent.removeChild(old[i]);
        }
    }

    function morphElement(o, n) {
        for (const attr of Array.from(o.attributes)) {
            if (!n.hasAttribute(attr.name)) o.removeAttribute(attr.name);
        }
        for (const attr of Array.from(n.attributes)) {
            if (o.getAttribute(attr.name) !== attr.value) o.setAttribute(attr.name, attr.value);
        }
        o.__on = n.__on;
        bind(o);
        if (o.localName === 'input') {
            if (o.type === 'checkbox') {
                o.checked = n.hasAttribute('checked');
            } else if (document.activeElement !== o && n.hasAttribute('value')) {
                o.value = n.getAttribute('value');
            }
        }
        morphChildren(o, Array.from(n.childNodes));
    }

    function mount() {
        const root = document.querySelector('x-dc');
        const script = document.querySelector('script[type="text/x-dc"]');
        if (!root || !script) {
            return;
        }

        // Detach the template so its on* attributes never run as inline handlers.
        const template = document.createDocumentFragment();
        while (root.firstChild) {
            template.appendChild(root.firstChild);
        }
        template.querySelectorAll('helmet').forEach((helmet) => {
            while (helmet.firstChild) document.head.appendChild(helmet.firstChild);
            helmet.remove();
        });
        root.style.display = 'block';

        const declared = JSON.parse(script.getAttribute('data-props') || '{}');
        const props = {};
        for (const [key, spec] of Object.entries(declared)) {
            if (!key.startsWith('$') && spec && 'default' in spec) props[key] = spec.default;
        }
        new URLSearchParams(location.search).forEach((value, key) => {
            props[key] = value === 'true' ? true : value === 'false' ? false : value;
        });

        const Component = new Function('DCLogic', script.textContent + '\nreturn Component;')(DCLogic);
        const component = new Component(props);
        component._render = () => {
            let values;
            try {
                values = component.renderVals();
            } catch (e) {
                console.error(e);
                return;
            }
            const out = [];
            template.childNodes.forEach((c) => build(c, values, out));
            morphChildren(root, out);
        };
        component._render();
        if (component.componentDidMount) component.componentDidMount();
        window.addEventListener('pagehide', () => component.componentWillUnmount && component.componentWillUnmount());
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', mount);
    } else {
        mount();
    }
})();
