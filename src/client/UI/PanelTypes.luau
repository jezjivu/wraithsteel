--!strict
-- PanelTypes: the contract every UI panel module follows (UIController drives them).

export type Ctx = {
	atStation: boolean, -- opened from the station in the hub (buying allowed)
	lanternId: string?, -- Lantern Shrine pedestal that was used, if any
	refresh: () -> (), -- re-render this panel
	close: () -> (),
	notify: (text: string, isError: boolean?) -> (),
}

export type Panel = {
	Title: string,
	WatchKeys: { string }, -- re-render when any of these profile keys change
	Changed: any?, -- optional Signal: re-render whenever it fires (non-profile state)
	Render: (body: ScrollingFrame, ctx: Ctx) -> (),
}

return {}
