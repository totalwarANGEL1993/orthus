-- ########################################################################## --
-- #  Library Loader                                                        # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

gvBasePath = gvBasePath or "data/maps/externalmap/";

Script.Load(gvBasePath.. "qsb/lib/oop.lua");

Script.Load(gvBasePath.. "qsb/lib/quest/questcore.lua");
Script.Load(gvBasePath.. "qsb/lib/quest/questtools.lua");
Script.Load(gvBasePath.. "qsb/lib/quest/questsync.lua");
Script.Load(gvBasePath.. "qsb/lib/quest/questsystem.lua");
Script.Load(gvBasePath.. "qsb/lib/quest/questbriefing.lua");
Script.Load(gvBasePath.. "qsb/lib/quest/questdebug.lua");
Script.Load(gvBasePath.. "qsb/lib/quest/questbehavior.lua");
Script.Load(gvBasePath.. "qsb/lib/quest/questtreasure.lua");

Script.Load(gvBasePath.. "qsb/lib/ui/speed.lua");
Script.Load(gvBasePath.. "qsb/lib/ui/onscreeninfo.lua");
Script.Load(gvBasePath.. "qsb/lib/ui/workplace.lua");
Script.Load(gvBasePath.. "qsb/lib/ui/optionsmenu.lua");
Script.Load(gvBasePath.. "qsb/lib/ui/interaction.lua");

Script.Load(gvBasePath.. "qsb/lib/ai/aitrooprecruiter.lua");
Script.Load(gvBasePath.. "qsb/lib/ai/aitroopspawner.lua");
Script.Load(gvBasePath.. "qsb/lib/ai/aiarmy.lua");
Script.Load(gvBasePath.. "qsb/lib/ai/aicontroller.lua");

Script.Load(gvBasePath.. "qsb/ext/loader.lua");

Script.Load(gvBasePath.. "s5c/s5CommunityLib/packer/devload.lua");

-- only if community lib is found
if mcbPacker then
    mcbPacker.Paths = {
        {gvBasePath.. "s5c/", ".lua"},
        {gvBasePath.. "s5c/", ".luac"}
    }
    
    mcbPacker.require("s5CommunityLib/tables/ArmorClasses");
    mcbPacker.require("s5CommunityLib/tables/AttachmentTypes");
    mcbPacker.require("s5CommunityLib/tables/EntityAttachments");
    mcbPacker.require("s5CommunityLib/tables/LeaderFormations");
    mcbPacker.require("s5CommunityLib/tables/MouseEvents");
    mcbPacker.require("s5CommunityLib/tables/TerrainTypes");
    mcbPacker.require("s5CommunityLib/tables/animTable");

    mcbPacker.require("s5CommunityLib/comfort/math/Lerp");
    mcbPacker.require("s5CommunityLib/comfort/math/Polygon");
    mcbPacker.require("s5CommunityLib/comfort/math/Vector");
    mcbPacker.require("s5CommunityLib/comfort/pos/IsInCone");
    mcbPacker.require("s5CommunityLib/comfort/table/CopyTable");
end