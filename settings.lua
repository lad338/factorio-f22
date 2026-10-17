-- Only declared when AircraftRealism is present -- without it there's
-- no grounded/airborne split to transition between.
if mods["AircraftRealism"] then
  data:extend({
    {
      type = "double-setting",
      name = "transition-speed-f22",
      setting_type = "runtime-global",
      minimum_value = 1,
      default_value = 150,
    },
  })
end
