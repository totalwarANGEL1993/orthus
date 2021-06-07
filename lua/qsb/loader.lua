-- ########################################################################## --
-- #  Library Loader                                                        # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

gvLibVersion = "2.0.0";
gvBasePath = gvBasePath or "data/maps/externalmap/";

Script.Load(gvBasePath.. "qsb/lib/oop.lua");
Script.Load(gvBasePath.. "qsb/lib/bugfixes.lua");

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

Script.Load(gvBasePath.. "qsb/s5c/s5communitylib/packer/devload.lua");

-- only if community lib is found
if mcbPacker then
    mcbPacker.mainPath = gvBasePath.. "qsb/s5c/s5communitylib/";
    
    mcbPacker.require("tables/ArmorClasses");
    mcbPacker.require("tables/AttachmentTypes");
    mcbPacker.require("tables/EntityAttachments");
    mcbPacker.require("tables/LeaderFormations");
    mcbPacker.require("tables/MouseEvents");
    mcbPacker.require("tables/TerrainTypes");
    mcbPacker.require("tables/animTable");

    mcbPacker.require("comfort/math/Lerp");
    mcbPacker.require("comfort/math/Polygon");
    mcbPacker.require("comfort/math/Vector");
    mcbPacker.require("comfort/pos/IsInCone");
    mcbPacker.require("comfort/table/CopyTable");

    mcbPacker.require("fixes/TriggerFix");
end