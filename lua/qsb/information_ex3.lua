-- ########################################################################## --
-- #  Interaction                                                           # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

--
-- This module is just the interface between the quest system and the briefing
-- code mcbBrief by mcb.
--
-- @set sort=true
--

Information = {};

--
-- Installs the information mod.
-- @within Information
-- @local
--
function Information:Install()
    self:OverrideCinematic();
end

--
-- Overrides the briefing functions that enter or leave the cinematic mode.
--
-- @within Information
-- @local
--
function Information:OverrideCinematic()
    if not mcbBrief then
        GUI.AddStaticNote("FATAL: Could not find mcbBrief!");
        return;
    end
    
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

    AddPages_Orig_Information = AddPages;
    AddPages = function(_briefing)
        local AP = AddPages_Orig_Information(_briefing);
        local ASP = function(...)
            if (table.getn(arg) == 7) then
                table.insert(arg, 1, -1);
            end
            table.insert(arg, true);
            return mcbBrief.createShortPage(unpack(arg));
        end
        local ASMC = function(...)
            if (table.getn(arg) == 11) then
                table.insert(arg, 1, -1);
            end
            table.insert(arg, 9, true);
            return mcbBrief.createShortMCPage(unpack(arg));
        end
        return AP, ASP, ASMC;
    end
end