-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --
-- ~~~                                                                    ~~~ --
-- ~~~                                                                    ~~~ --
-- ~~~                    MULTIPLAYER CONFIGURATION                       ~~~ --
-- ~~~                                                                    ~~~ --
-- ~~~                                                                    ~~~ --
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --

gvBasePath = "data/maps/externalmap/qsb/";
Script.Load(gvBasePath.. "mploader.lua");

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --
-- ~~~                            Ruleset                                 ~~~ --
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --

MPRuleset_Rules = {
    --~~ Initalisation
    --~~ Choose if rules should be changeable.
    --~~ You can also call your scripts in the callback functions below.
    
    -- Rules can be changed
    Changeable = true,

    Callbacks = {
        -- After the map has been loaded on all machines.
        OnMapLoaded = function()
        end,

        -- After configuration has been loaded
        OnMapConfigured = function()
        end,

        -- After peacetime ended (no peacetime means immediate execution after
        -- configuration is loaded)
        OnPeacetimeOver = function()
        end,
    },

    --~~ Resources
    --~~ Set the amount of starting resources for the three presets "normal",
    --~~ "plenty" and "insane".
    --~~ You can also define how much resources shoult be in the heaps.

    Resources = {
        -- Amount of resources in resource heaps
        ResourceHeapSize    = 2000,

        -- Choosen resource preset
        Choosen = 1,

        [1] = {
            Gold            = 1000,
            Clay            = 1500,
            Wood            = 1200,
            Stone           = 800,
            Iron            = 250,
            Sulfur          = 250,
        },
        [2] = {
            Gold            = 2000,
            Clay            = 3500,
            Wood            = 2400,
            Stone           = 1600,
            Iron            = 800,
            Sulfur          = 800,
        },
        [3] = {
            Gold            = 5000,
            Clay            = 8000,
            Wood            = 8000,
            Stone           = 5000,
            Iron            = 5000,
            Sulfur          = 5000,
        },
    },

    --~~ Timers
    --~~ Configure the timers for this game.
    --~~ Peacetime means that players can not attack each other until the time
    --~~ bar is full.
    --~~ DeathPenalty is a timer that indicates how much time is left until
    --~~ the objective must be reached. Per default the objectie is to kill
    --~~ all members of different teams. But you can easily add more quests
    --~~ that might add other objectives.

    Timer = {
        -- Peacetime in minutes (0 = off)
        Peacetime           = 20,

        -- Minutes until everyone loses (0 = off)
        DeathPenalty        = 0,
    },

    --~~ Commandment
    --~~ The commandments are a list of special rules that you can choose to
    --~~ activate or deacivate. They might make the game more enjoyable.

    Commandment = {
        -- Crush building glitch fixed. Buildings will deselect the building
        -- and then destroy it right away without warning. (0 = off)
        CrushBuilding       = 1,

        -- Formation tech fix (0 = off)
        -- Formations will only require GT_StandingArmy researched and not 
        -- GT_Tactics to also be allowed.
        Formaition          = 1,

        -- Associate village centers to players (0 = off)
        -- Give sequential names to village centers for each player. Players
        -- can not build village centers expect there where they allowed to.
        -- Example: (P1VC1, P1VC2, ..)
        AssociateVillages   = 0,

        -- Block HQ rush (0 = off)
        -- Player HQs can not be damaged until the player has village
        -- centers left.
        HQRushBlock         = 1,

        -- Bridges can not be destroyed (0 = off)
        InvincibleBridges   = 0,

        -- Control worker amount in workplaces (0 = off)
        Workplace           = 1,

        -- Minutes the weather can not be changed again after a change was
        -- triggered by the weather tower.
        WeatherChangeDelay  = 5 * 30,

        -- Minutes a player must wait between two blesses.
        BlessDelay          = 120,
    },

    --~~ Limits
    --~~ In this section you can set a limit to different units. Heroes can be
    --~~ limited between 0 and 6. Everything else is unlimited if set to -1,
    --~~ forbidden if 0 and limited to the amount if greater than 0.

    Limits = {
        -- Limit of heroes the player can buy
        Hero         = 3,

        -- Building Limit  (-1 = off)
        Market       = 1,
        Tower        = 5,
        University   = -1,
        Village      = -1,

        -- Unit limits (-1 = off)
        Bow          = -1,
        LightCavalry = -1,
        HeavyCavalry = -1,
        Rifle        = -1,
        Spear        = -1,
        Serf         = -1,
        Scout        = -1,
        Sword        = -1,
        Thief        = -1,

        -- vehicle limit (-1 = off)
        Cannon1      = -1,
        Cannon2      = -1,
        Cannon3      = -1,
        Cannon4      = -1,
    },

    --~~ Heroes
    --~~ Sets the heroes that are allowed in the game.

    -- Heroes available (0 = forbidden)
    Heroes = {
        Dario               = 1,
        Pilgrim             = 1,
        Salim               = 1,
        Erec                = 1,
        Ari                 = 1,
        Helias              = 1,
        Drake               = 1,
        Yuki                = 1,
        -- ---------- --
        Varg                = 1,
        Kerberos            = 1,
        Mary                = 1,
        Kala                = 1,
    },

    --~~ Technologies
    --~~ Limit the technologies for the game. Each branch is red from left
    --~~ to right. If the value is 0 then the branch is completly forbidden.
    --~~ For each number greater than 0 a technology in the branch is allowed.

    Technologies = {
        -- Gunsmith technologies
        Gunsmith            = {
            Rifle           = 2, -- Weapons branch (0 to 2)
            Armor           = 2, -- Armor branch (0 to 2)
        },

        -- Laboratory technologies
        Laboratory          = {
            Cannon          = 2, -- Cannon branch (0 to 2)
            Weather         = 2, -- Weather branch (0 to 2)
        },

        -- Masory technologies
        Masory              = {
            Walls           = 1, -- Building defence
        },

        Sawmill             = {
            Spearmen        = 2, -- Sear branch (0 to 2)
            Bowmen          = 2, -- Bow branch (0 to 2)
        },

        -- Smith technologies
        Smith               = {
            Light           = 3, -- Light armor branch (0 to 3)
            Heavy           = 3, -- Heavy armor branch (0 to 3)
            Weapons         = 2, -- Weapon branch (0 to 2)
        },

        -- University technologies
        University          = {
            Construction    = 4, -- Construction branch (0 to 4)
            Civil           = 4, -- Civil branch (0 to 4)
            Industrial      = 4, -- Industrial branch (0 to 4)
            Millitary       = 4, -- Millitary branch (0 to 4)
            Addon           = 4, -- Addon branch (0 to 4)
        },

        Village             = {
            Civil           = 3, -- Village center (0 to 3)
        }
    },
};

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --
-- ~~~                          User Script                               ~~~ --
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --


