-- Radiojoy: the border follows the wallpaper (Alastor / Emily / both).
-- radiojoy-sync writes the gradient for the current wallpaper to
-- ~/.local/state/omarchy/radiojoy-border; this falls back to crimson → gold → periwinkle.
local state = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/omarchy/radiojoy-border"
local colors = {}
local f = io.open(state, "r")
if f then
  for c in f:read("*a"):gmatch("rgba%(%x+%)") do colors[#colors + 1] = c end
  f:close()
end
if #colors == 0 then colors = { "rgba(dc2249ee)", "rgba(f2c14eee)", "rgba(7d82bcee)" } end

local active_border_color = { colors = colors, angle = 45 }
local inactive_border_color = "rgba(2b1a1daa)"

hl.config({
  general = {
    col = {
      active_border = active_border_color,
      inactive_border = inactive_border_color,
    },
  },

  group = {
    col = {
      border_active = active_border_color,
      border_inactive = inactive_border_color,
    },
  },
})
