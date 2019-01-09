-- ########################################################################## --
-- #  Interaction Loader                                                    # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

local Version = Framework.GetProgramVersion();
gvExtensionNumber = tonumber(string.sub(Version, string.len(Version)));
if gvExtensionNumber > 2 then
    Script.Load("data/maps/externalMap/qsb/information_ex3.lua");
else
    Script.Load("data/maps/externalMap/qsb/information_ex2.lua");
end
