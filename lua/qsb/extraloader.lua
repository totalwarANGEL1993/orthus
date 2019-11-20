-- ########################################################################## --
-- #  Extra Loader                                                          # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

-- Loads scripts depending on the game version
-- TODO: Add History Edition fix
local Version = Framework.GetProgramVersion();
gvExtensionNumber = tonumber(string.sub(Version, string.len(Version)));
if gvExtensionNumber > 2 then
    Script.Load(gvBasePath.. "qsb/information_ex3.lua");
    Script.Load(gvBasePath.. "qsb/timer_ex3.lua");
else
    Script.Load(gvBasePath.. "qsb/information_ex2.lua");
    Script.Load(gvBasePath.. "qsb/speed_ex2.lua");
    Script.Load(gvBasePath.. "qsb/timer_ex2.lua");
    Script.Load(gvBasePath.. "qsb/workplace_ex2.lua");
    Script.Load(gvBasePath.. "qsb/s5hook_ex2.lua");
end
-- Load allways
Script.Load(gvBasePath.. "qsb/treasure.lua");
