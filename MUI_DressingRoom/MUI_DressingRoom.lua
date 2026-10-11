-- MUI_DressingRoom: retail's dressing room on Classic Era — the window a
-- Ctrl-click on an item opens.
--
--   MUI_DressingRoomFrame   the window, on Era's own DressUpFrame: the
--                           chrome, the class backdrop, the two sizes
--   MUI_DressingRoomModel   Era's model with retail's handling and control bar
--
-- Not carried over from retail, which Era has nothing for: the saved outfits
-- (their dropdown, the list of what is worn beside the window, the Link
-- button) are transmog's. The room beside the auction house is another frame
-- (SideDressUpFrame), which retail left in its old art too.

object "ModuleDressingRoom" : extends "Module" {
    __init = function(self)
        Module.__init(self, "DressingRoom")
    end;

    OnEnable = function(self)
        self.window = DressingRoomWindow()
    end;
}
