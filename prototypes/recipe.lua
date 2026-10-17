-- The "f22" item prototype lives in prototypes/entity/f22.lua, not here
-- -- the entity's `minable.result` needs it to already exist. This file
-- only adds the recipe that crafts it.
data:extend({
  {
    type = "recipe",
    name = "f22",
    enabled = false,
    energy_required = 10,
    ingredients = {
      {type = "item", name = "engine-unit", amount = 48},
      {type = "item", name = "steel-plate", amount = 75},
      {type = "item", name = "iron-gear-wheel", amount = 25},
      {type = "item", name = "advanced-circuit", amount = 15},
    },
    results = {{type = "item", name = "f22", amount = 1}},
  },
})
