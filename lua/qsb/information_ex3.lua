-- ########################################################################## --
-- #  Interaction                                                           # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

---
-- This module is just the interface between the quest system and the briefing
-- code mcbBrief by mcb.
--
-- @set sort=true
--

Information = {};

---
-- Installs the information mod.
-- @within Information
-- @local
--
function Information:Install()
    self:OverrideCinematic();
end

---
-- Overrides the briefing functions that enter or leave the cinematic mode.
--
-- @within Information
-- @local
--
function Information:OverrideCinematic()
    StartBriefing_Orig_Information = StartBriefing;
    StartBriefing = function(_briefing)
        assert(type(_briefing) == "table");
        local ID = StartBriefing_Orig_Information(_briefing);
        if XGUIEng.IsWidgetShown("GameClock") == 1 then
			XGUIEng.ShowWidget("GameClock", 0);
			gvGameClockWasShown = true;
        end
		Game.GameTimeReset();
        GUI.ClearNotes();
        return ID;
    end

    EndBriefing_Orig_Information = EndBriefing;
    EndBriefing = function()
        EndBriefing_Orig_Information();
        if gvGameClockWasShown then
			XGUIEng.ShowWidget("GameClock", 1);
			gvGameClockWasShown = false;
        end
    end
end