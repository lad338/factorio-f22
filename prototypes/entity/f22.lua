local ICONPATH = "__f22Raptor__/graphics/icons/"
local ENTITYPATH = "__f22Raptor__/graphics/entity/f22/"
local FRAME_SIZE = 512  -- must match the rendered frame size in graphics/entity/f22/

local function f22_animation()
  return {
    layers = {
      {
        filename = ENTITYPATH .. "f22-spritesheet.png",
        width = FRAME_SIZE,
        height = FRAME_SIZE,
        frame_count = 1,
        direction_count = 36,
        line_length = 6,
        -- Rendered at 2x (64px/tile) for quality, downscaled via `scale`.
        scale = 0.5,
        shift = {0, 0},
      },
      {
        filename = ENTITYPATH .. "f22-spritesheet-shadow.png",
        width = FRAME_SIZE,
        height = FRAME_SIZE,
        frame_count = 1,
        direction_count = 36,
        line_length = 6,
        scale = 0.5,
        -- Without an offset this sits directly under the opaque main
        -- layer and is invisible; slight southwest offset to show it.
        shift = util.by_pixel(-10, 8),
        draw_as_shadow = true,
      },
    },
  }
end

data:extend({
  {
    type = "car",
    name = "f22",
    icon = ICONPATH .. "f22-icon.png",
    icon_size = 64,
    flags = {"placeable-neutral", "player-creation", "placeable-off-grid"},
    minable = {mining_time = 1, result = "f22"},
    collision_box = {{-1.1, -1.6}, {1.1, 1.6}},
    selection_box = {{-1.1, -1.6}, {1.1, 1.6}},
    -- Full flight by default; narrowed back to real collision on the
    -- grounded copy below when AircraftRealism is present.
    collision_mask = {layers = {}},
    render_layer = "air-object",
    final_render_layer = "air-object",
    selection_priority = 60,
    animation = f22_animation(),
    max_health = 2000,
    energy_per_hit_point = 0.8,
    -- physical/impact/explosion match vanilla tank; fire/acid kept at
    -- their original flying-fortress-derived values.
    resistances = {
      {type = "fire", decrease = 0, percent = 100},
      {type = "physical", decrease = 15, percent = 60},
      {type = "impact", decrease = 50, percent = 80},
      {type = "explosion", decrease = 15, percent = 70},
      {type = "acid", decrease = 60, percent = 20},
    },
    guns = {"f22-machine-gun", "f22-rocket-launcher", "f22-rocket-launcher", "f22-rocket-launcher"},
    equipment_grid = "f22-equipment-grid",
    inventory_size = 20,
    trash_inventory_size = 10,
    energy_source = {
      type = "burner",
      fuel_inventory_size = 8,
    },
    consumption = "1850kW",
    effectivity = 1,
    weight = 1000,
    braking_force = 3000 * 1000 / 60,
    friction_force = 0.0005,
    stop_trigger_speed = 0.1,
    acceleration_per_energy = 0.5,
    breaking_speed = 0.1,
    rotation_speed = 0.01,
    allow_remote_driving = true,
    terrain_friction_modifier = 0,
    create_ghost_on_death = false,
    corpse = "medium-remnants",
    dying_explosion = "medium-explosion",
    minimap_representation = {
      filename = ENTITYPATH .. "f22-map.png",
      flags = {"icon"},
      size = {64, 64},
    },
    selected_minimap_representation = {
      filename = ENTITYPATH .. "f22-map.png",
      flags = {"icon"},
      size = {64, 64},
    },
  },
  {
    -- Co-located with the entity, not in recipe.lua, because
    -- `minable.result` above forward-references this item by name and
    -- Factorio validates that at the end of the full data stage.
    type = "item-with-entity-data",
    name = "f22",
    icon = ICONPATH .. "f22-icon.png",
    icon_size = 64,
    subgroup = "transport",
    order = "b[personal-transport]-z[f22]",
    place_result = "f22",
    stack_size = 1,
  },
})

-- "normal Factorio fuel": reuse vanilla car's own fuel categories.
-- Deep-copied, not assigned by reference -- a shared reference would
-- let a later mod's data-final-fixes.lua (e.g. kj_fuel) silently alter
-- this table too, and could desync the grounded/flying copies below
-- depending on when that happens relative to their own deepcopy.
data.raw["car"]["f22"].energy_source.fuel_categories = table.deepcopy(data.raw["car"]["car"].energy_source.fuel_categories)

if mods["AircraftRealism"] then
  local arapi = require("__AircraftRealism__.api")

  local f22_grounded = data.raw["car"]["f22"]
  local f22_flying = table.deepcopy(f22_grounded)
  f22_flying.name = "f22-flying"

  f22_grounded.collision_box = f22_grounded.selection_box
  -- Restore real ground collision on the taxiing copy; nil falls back
  -- to car's own default mask (only f22-flying stays collision-free).
  f22_grounded.collision_mask = nil
  f22_grounded.render_layer = "object"
  f22_grounded.friction_force = f22_grounded.friction_force * 0.5

  f22_flying.animation.layers[2] = nil -- shadow managed dynamically by AircraftRealism
  f22_flying.collision_mask = {layers = {}}
  f22_flying.effectivity = f22_flying.effectivity / 4
  f22_flying.friction_force = f22_flying.friction_force / 6
  f22_flying.braking_force = f22_flying.braking_force / 2
  data:extend({f22_flying})

  local spriteNames = {}
  for i = 0, 35 do
    local xPos = i % 6
    local yPos = math.floor(i / 6)
    spriteNames[i + 1] = "f22-shadow-" .. tostring(i)
    data:extend({{
      type = "sprite",
      name = "f22-shadow-" .. tostring(i),
      filename = "__f22Raptor__/graphics/entity/f22/f22-spritesheet-shadow.png",
      width = FRAME_SIZE,
      height = FRAME_SIZE,
      x = xPos * FRAME_SIZE,
      y = yPos * FRAME_SIZE,
      scale = 0.5,
      shift = {0, 0},
    }})
  end

  -- "transition-speed-f22" itself is declared in settings.lua -- setting
  -- prototypes can only be created during the settings stage, not here.
  arapi.register_plane({
    grounded_name = f22_grounded.name,
    airborne_name = f22_flying.name,
    transition_speed_setting = "transition-speed-f22",
    shadow_sprite = spriteNames,
    -- Speed above which the dynamic shadow stops rendering; AircraftRealism's
    -- own default (10 km/h) is far below cruising speed, so the shadow
    -- would vanish almost immediately in real flight.
    shadow_end_speed = 500 * (1000 / (60 * 60 * 60)),
    shadow_offset = {50, 20},
  })
end
