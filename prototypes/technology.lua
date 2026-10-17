data:extend({
  {
    type = "technology",
    name = "f22",
    -- Dedicated 256x256 render -- tech-tree icons display much larger
    -- than the 64x64 inventory icon (matches vanilla's own convention).
    icon = "__f22__/graphics/icons/f22-icon-tech.png",
    icon_size = 256,
    effects = {
      {type = "unlock-recipe", recipe = "f22"},
    },
    prerequisites = {"automobilism", "military-3", "rocketry"},
    unit = {
      count = 400,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"military-science-pack", 1},
      },
      time = 30,
    },
  },
})
