require("util")
require("gui")

local name = "breakmapper"

Model = {
  width = 1000,
  unselected = {},
  selected = {},

  note = 48,
  octave = 4,
  vel_step = 1,

  note_op = 1,
  vel_op = 1,

  vel_equal_mode = 1,
  vel_fixed_mode = 1,

  vel_to_vol = 3,
  key_to_pitch = 3,

  auto_apply = true,
  dirty = false,

  follow_selection = false,
}

function default_prefs()
  return {
  }
end

local prefs = renoise.Document.create("ScriptingToolPreferences")(default_prefs())

local tool = renoise.tool()
tool.preferences = prefs

local dialog = nil

local KEY_TO_PITCH_OPS = {
  "Keep",
  "On",
  "Off",
}

local VEL_TO_VOL_OPS = {
  "Keep",
  "On",
  "Off",
}

local NOTE_OPS = {
  "Keep",
  "Single",
  "Octaves",
  "Reset",
}

local VEL_OPS = {
  "Keep",
  "Equal",
  "Fixed",
  "Reset",
}

local VEL_EQUAL_MODE = {
  "Distribute",
  "Extend Highest",
  "Extend Lowest",

  -- "Shrink Lowest",
}

local VEL_FIXED_MODE = {
  "From Lowest",
  "From Highest",
}

function modify_keyzones(m)
  if #m.selected == 0 then
    return
  end
  local s = renoise.song()
  local instrument = s.selected_instrument
  local vel_step = 1
  local vel_left_over = 128 % #m.selected
  print(vel_left_over, vel_step)

  local distributed = 0
  for sel_i = 1, #m.selected do
    local i = math.fmod(sel_i,128)
    local note = math.floor((sel_i - 1 ) / 128) + (12*3)
    if i > 0 and i <= 128 then
      local sm = instrument.sample_mappings[1][m.selected[sel_i].index]

      -- equal velocity stack
      local range_start = 0

      if i > 1 then
        range_start = instrument.sample_mappings[1][m.selected[sel_i - 1].index].velocity_range[2] + 1
      end

      local range_end = range_start + vel_step - 1

      local step_size = 1
      range_end = range_start + step_size - 1

      if i == #m.selected then
        range_end = 128
      end

      sm.velocity_range = { clamp(range_start, 0, 128), clamp(range_end, 0, 128) }
      -- singe note
      sm.base_note = note
      sm.note_range = { note, note}

      sm.map_velocity_to_volume = false
      sm.map_key_to_pitch = false

    end
  end
end
function on_instrument_change()
  if dialog ~= nil then
    open()
  end
end

function on_sample_change()
  if Model.follow_selection then
    if dialog then
      dialog.process(dialog.model, message("toggle sample", renoise.song().selected_sample_index), dialog)
    end
  end
end

renoise.tool().app_became_active_observable:add_notifier(function()
  local hook_notifiers = function()
    enable_notifier(renoise.song(), "selected_sample", on_sample_change)
    enable_notifier(renoise.song(), "selected_instrument", on_instrument_change)
  end

  enable_notifier(renoise.tool(), "app_new_document", hook_notifiers)

  hook_notifiers()
end)

renoise.tool().app_release_document_observable:add_notifier(function()
  if dialog then
    if dialog.window.visible then
      dialog.window:close()
    end
    dialog = nil
  end
end)

function init(m)
  m.unselected = renoise.song().selected_instrument.samples
  m.dirty = false
  -- SILLY
  return m
end

function update(m, msg)
  if msg.type == "select sample" then
    if not m.follow_selection then
      renoise.song().selected_sample_index = msg.value
    end
    table.insert(m.selected, { index = msg.value, name = renoise.song().selected_sample.name })
    m.vel_step = 1
  elseif msg.type == "unselect sample" then
    table.remove(m.selected, msg.value)
  elseif msg.type == "toggle sample" then
    local i = table:find_index(m.selected, function(a)
      return a.index == msg.value
    end)
    if i > 0 then
      table.remove(m.selected, i)
    else
      table.insert(m.selected, { index = msg.value, name = renoise.song().selected_sample.name })
    end
  elseif msg.type == "select note" then
    m.note = m.octave * 12 + msg.value - 1
  elseif msg.type == "select octave" then
    m.octave = msg.value - 1
    m.note = m.octave * 12 + (m.note % 12)
  elseif msg.type == "set note op" then
    m.note_op = msg.value

  elseif msg.type == "set vel op" then
    m.vel_op = msg.value
  elseif msg.type == "set vel step" then
    m.vel_step = msg.value
  elseif msg.type == "set vel equal mode" then
    m.vel_equal_mode = msg.value
  elseif msg.type == "set vel fixed mode" then
    m.vel_fixed_mode = msg.value
  elseif msg.type == "set vel vol" then
    m.vel_to_vol = msg.value
  elseif msg.type == "set key pitch" then
    m.key_to_pitch = msg.value
  elseif msg.type == "set auto apply" then
    m.auto_apply = msg.value
  elseif msg.type == "apply" then
    modify_keyzones(m)
  elseif msg.type == "Invert Selection" then
    local ls = {}
    for i = 1, #m.unselected do
      if not prop_with_value_exist_in_table("index", i, m.selected) then
        table.insert(ls, { index = i, name = m.unselected[i].name })
      end
    end
    m.selected = ls
    m.vel_step = 1
  elseif msg.type == "Reverse" then
    m.selected = table:reverse(m.selected)
  elseif msg.type == "Shuffle" then
    m.selected = table:shuffle(m.selected)
  elseif msg.type == "move up" then
    if msg.value > 1 then
      table:swap(m.selected, msg.value, msg.value - 1)
    end
  elseif msg.type == "move down" then
    if msg.value < #m.selected then
      table:swap(m.selected, msg.value, msg.value + 1)
    end
  elseif msg.type == "Clear" then
    m.selected = {}
  elseif msg.type == "Select All" then
    m.selected = table:map(m.unselected, function(s, i)
      return {
        index = i,
        name = s.name
      }
    end)
    m.vel_step = 1
  elseif msg.type == "quit" then
    return 1
  end

  if m.auto_apply then
    modify_keyzones(m)
  else
    m.dirty = msg.type ~= "apply"
  end
  return 0
end

function view(m, o)
  local vb = renoise.ViewBuilder()
  local process = function(name, value)
    return function()
      o.process(m, message(name, value), o)
    end
  end
  local process_button = function(name, visible, value, text)
    return vb:button {
      text = text and text or name,
      visible = ifelse(visible == nil, true, visible),
      pressed = process(name, value),
    }
  end
  local w = m.width - 15 * 2
  local content = vb:column {
    width = m.width,
    margin = 15,
    spacing = 5,
    vb:row {
      -- style = "group",
      width = w,
      vb:column {
        width = w / 2,

        vb:row {
          spacing = 5,
          -- style = "group",
          process_button("Select All", #m.unselected > #m.selected),
          process_button("Invert Selection", #m.unselected > #m.selected and #m.selected > 0),

        },
        empty_row(),
        list_view(
            m.unselected,
            function(s, i)
              -- local pre = renoise.song().selected_sample_index == i and " > " or ""
              return vb:button {
                text = s.name,
                width = w / 2,
                visible = not prop_with_value_exist_in_table("index", i, m.selected),
                pressed = function()
                  o.process(m, message("select sample", i), o)
                end,
              }
            end
        )
      },
      vb:column {
        width = w / 2,
        vb:horizontal_aligner {
          mode = "right",
          -- spacing = 5,
          -- style = "group",
          process_button("Clear", #m.selected > 1),
          process_button("Shuffle", #m.selected > 1),
          process_button("Reverse", #m.selected > 1),
        },
        vb:row {
          visible = #m.selected == 1,
          vb:text {
          }
        },
        empty_row(),

        list_view(
            m.selected,
        --   renoise.song().selected_instrument.samples,
            function(s, i)
              local aw = 20
              -- local pre = renoise.song().selected_sample_index == i and " > " or ""
              return vb:row {
                vb:button {
                  width = w / 2 - aw * 2,
                  text = s.name,
                  pressed = function()
                    o.process(m, message("unselect sample", i), o)
                    -- print(s.name)
                    -- select_sample(s.name, i)
                  end,
                },
                vb:button {
                  width = aw,
                  text = "↑",
                  pressed = process("move up", i)
                },
                vb:button {
                  width = aw,
                  text = "↓",
                  pressed = process("move down", i)
                },
              }
            end
        ),
        vb:row {
          visible = #m.selected > 0,
          vb:text {
            width = w / 2 - 5,
            align = "right",
            style = "disabled",
            text = #m.selected .. " selected"
          }
        },
      },
    },
    vb:column {
      width = w,
      visible = #m.selected > 0,
      empty_row(),
      vb:row {
        vb:text {
          width = w,
          align = "center",
          text = "Velocity",
        }
      },
      vb:row {
        vb:switch {
          width = w,
          value = m.vel_op,
          items = VEL_OPS,
          notifier = function(v)
            o.process(m, message("set vel op", v), o)
          end
        }
      },
      vb:row {
        visible = m.vel_op == 2,
        vb:switch {
          width = w,
          value = m.vel_equal_mode,
          items = VEL_EQUAL_MODE,
          notifier = function(v)
            o.process(m, message("set vel equal mode", v), o)
          end
        }
      },
      vb:horizontal_aligner {
        mode = "distribute",
        visible = m.vel_op == 3,
        vb:text {
          -- width = w / 2,
          align = "right",
          text = "Step Size",
        },
        vb:valuebox {
          value = m.vel_step,
          min = 1,
          max = 16,
          notifier = function(v)
            m.vel_step = v
            if m.auto_apply then
              modify_keyzones(m)
            end
          end
        },
        vb:switch {
          width = w / 2,
          value = m.vel_fixed_mode,
          items = VEL_FIXED_MODE,
          notifier = function(v)
            o.process(m, message("set vel fixed mode", v), o)
          end
        },
      },
      empty_row(),
      vb:row {
        vb:text {
          width = w,
          align = "center",
          text = "Note",
        }
      },
      vb:row {
        vb:switch {
          width = w,
          value = m.note_op,
          items = NOTE_OPS,
          notifier = function(v)
            o.process(m, message("set note op", v), o)
          end
        }
      },
      vb:row {
        visible = m.note_op == 2 or m.note_op == 3,
        vb:column {
          vb:row {
            vb:switch {
              width = w,
              value = (m.note % 12) + 1,
              items = NOTE_NAMES,
              notifier = function(v)
                o.process(m, message("select note", v), o)
              end,
            },

          },
          vb:row {
            vb:switch {
              width = w,
              value = m.octave + 1,
              items = OCTAVES,
              notifier = function(v)
                o.process(m, message("select octave", v), o)
              end,
            }
          }
        }
      },
      empty_row(),
      vb:row {
        vb:column {
          vb:row {
            vb:text {
              width = w / 2 - 15,
              align = "center",
              text = "Key -> Pitch",
            }
          },
          vb:row {
            vb:switch {
              width = w / 2 - 15,
              value = m.key_to_pitch,
              items = KEY_TO_PITCH_OPS,
              notifier = function(v)
                o.process(m, message("set key pitch", v), o)
              end
            }
          },
        },
        vb:column {
          width = 30,
        },
        vb:column {
          vb:row {
            vb:text {
              width = w / 2 - 15,
              align = "center",
              text = "Velocity -> Volume",
            }
          },
          vb:row {
            vb:switch {
              width = w / 2 - 15,
              value = m.vel_to_vol,
              items = VEL_TO_VOL_OPS,
              notifier = function(v)
                o.process(m, message("set vel vol", v), o)
              end
            }
          },
        },
      },
    },
    vb:horizontal_aligner {
      spacing = 5,
      margin = 5,
      vb:checkbox {
        value = m.auto_apply,
        notifier = function(b)
          o.process(m, message("set auto apply", b), o)
        end
      },
      vb:text {
        text = "Auto Apply",
        style = m.auto_apply and "normal" or "disabled"
      },
    },
    vb:button {
      width = w,
      visible = not m.auto_apply and #m.selected > 0 and m.dirty,
      text = "Apply Now",
      pressed = process("apply")
    },
  }

  return content
end

function open()
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_KEYZONES
  if dialog then
    if dialog.window.visible then
      dialog.window:close()
    end
    dialog = nil
  end

  local options = {
    title = name,

    model = Model,

    init = init,
    update = update,
    view = view,

    on_exit = function()
      dialog = nil
    end
  }

  dialog = model_view_dialog(options)
end

tool:add_menu_entry {
  name = "Main Menu:Tools:" .. name,
  invoke = function()
    open()
  end
}

tool:add_menu_entry {
  name = "Sample Mappings:breakmapper - Stack...",
  invoke = open
}

tool:add_keybinding {
  name = "Global:Tools:Open zoner",
  invoke = open
}

_AUTO_RELOAD_DEBUG = function()
end

print(name .. " loaded.")