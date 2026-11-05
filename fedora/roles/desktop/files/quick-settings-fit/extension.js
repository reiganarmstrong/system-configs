// GNOME sizes the quick settings columns from every toggle, hidden ones
// included. Hidden toggles keep the style they had before PaperWM loaded
// user.css, so their stock width stops the menu from shrinking. This is
// GNOME 51's QuickSettingsLayout._getMaxChildWidth, skipping hidden children.
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

function getVisibleMaxChildWidth(container) {
    let [minWidth, natWidth] = [0, 0];

    for (const child of container) {
        if (child === this._overlay || !child.visible)
            continue;

        const [childMin, childNat] = child.get_preferred_width(-1);
        const colSpan = this._getColSpan(container, child);
        minWidth = Math.max(minWidth, childMin / colSpan);
        natWidth = Math.max(natWidth, childNat / colSpan);
    }

    return [minWidth, natWidth];
}

export default class QuickSettingsFit extends Extension {
    enable() {
        this._grid = Main.panel.statusArea.quickSettings.menu._grid;
        this._proto = Object.getPrototypeOf(this._grid.layout_manager);
        this._original = this._proto._getMaxChildWidth;
        this._proto._getMaxChildWidth = getVisibleMaxChildWidth;
        this._grid.queue_relayout();
    }

    disable() {
        this._proto._getMaxChildWidth = this._original;
        this._grid.queue_relayout();
        this._grid = this._proto = this._original = null;
    }
}
