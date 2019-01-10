-- ########################################################################## --
-- #  Interaction Loader                                                    # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

-- Decides which briefing system to load.
local Version = Framework.GetProgramVersion();
gvExtensionNumber = tonumber(string.sub(Version, string.len(Version)));
if gvExtensionNumber > 2 then
    Script.Load(gvBasePath.. "qsb/information_ex3.lua");
else
    Script.Load(gvBasePath.. "qsb/information_ex2.lua");
end
