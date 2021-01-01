-- ########################################################################## --
-- #  Extra Loader                                                          # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

-- Loads scripts depending on the game version
-- TODO: Add History Edition fix
local Version = Framework.GetProgramVersion();
gvExtensionNumber = tonumber(string.sub(Version, string.len(Version)));
if gvExtensionNumber ~= nil and gvExtensionNumber > 2 then
    Script.Load(gvBasePath.. "qsb/ext/onscreeninfo_ex3.lua");
    Script.Load(gvBasePath.. "qsb/ext/information_ex3.lua");
else
    Script.Load(gvBasePath.. "qsb/ext/speed_ex2.lua");
    Script.Load(gvBasePath.. "qsb/ext/onscreeninfo_ex2.lua");
    Script.Load(gvBasePath.. "qsb/ext/workplace_ex2.lua");
end
-- Load allways
Script.Load(gvBasePath.. "qsb/ext/optionsmenu.lua");
Script.Load(gvBasePath.. "qsb/ext/interaction.lua");
Script.Load(gvBasePath.. "qsb/ext/troopgenerator.lua");

