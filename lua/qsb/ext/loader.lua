-- ########################################################################## --
-- #  Library Loader                                                        # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

--
-- Loads libraries used by the QSB if they are not already present.
--
-- Libraries loaded (in this order):
-- <ul>
-- <li>Metatable (mcb) - Makes metatables savable.</li>
-- <li>SVLib (schmeling65) - Accessing entity scripting values.</li>
-- to History Edition).</li>
-- </ul>
--
-- @set sort=true
--

-- Load Metatable fix
if metatable == nil then
    Script.Load(gvBasePath.. "qsb/ext/metatable.lua");
end
-- Scripting Values
if SVLib == nil then
    Script.Load(gvBasePath.. "qsb/ext/svlib.lua");
end

