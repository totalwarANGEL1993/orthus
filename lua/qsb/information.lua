-- ########################################################################## --
-- #  Interaction Loader                                                    # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

---
-- This module loads the information for either the vanilla game (extra1 and
-- extra2) or the community addon (extra3).
--
-- @set sort=true
--
local Version = Framework.GetProgramVersion();
gvExtensionNumber = tonumber(string.sub(Version, string.len(Version)));
if gvExtensionNumber > 2 then
    Script.Load("data/maps/externalMap/qsb/information_ex3.lua");
else
    Script.Load("data/maps/externalMap/qsb/information_ex2.lua");
end
