function message(t, v)
  return {
    type = t,
    value = v
  }
end

function toggle_row(vb, text, value, fun)
  return vb:row{
    spacing = 10,
    vb:checkbox {
      value = value,
      notifier = fun,
    },
    vb:text { 
      text = text
    },
  }
end

function model_view_dialog(o)
  o.model = o.init(o.model)

  local vb = renoise.ViewBuilder()
  o.view_container =  vb:column{
    width = o.width
  }

  o.has_view = false

  o.render = function(m)
    if o.has_view then
      -- oprint(View)
      o.view_container:remove_child(o.model_view)
      o.has_view = false
    end
    o.model_view = o.view(o.model, o)
    o.has_view = true
    o.view_container:add_child(o.model_view)
  end

  o.process = function(m, msg, o)
    local exit_code = o.update(m, msg, o)
    if exit_code == 0 then
      o.render(m)
    else
      if o.window.visible then
        o.window:close()
      end
      if o.on_exit then 
        o.on_exit(exit_code, o.model, o)
      end
      o = nil
    end
  end
  
  o.key_press = o.key_press and o.key_press or function(e)
    if e.name == "esc" then
      return message("quit", 1)
    end
    return nil
  end

  o.key_down = function(target, event)
    local msg = o.key_press(event, o.model, o)
    if msg ~= nil then
      o.process(o.model, msg, o)
    end
  end

  o.update(o.model, message("init", 0))
  o.render(o.model)

  o.window = renoise.app():show_custom_dialog(o.title, o.view_container, o.key_down)

  return o
end

function empty_row(text)
  local vb = renoise.ViewBuilder()
  return vb:row{
    vb:text{
      text = text
    }
  }
end

function list_view(list, fn)
  local vb = renoise.ViewBuilder()
  local ls = vb:vertical_aligner{
    spacing = 0,
  }
  for i = 1, #list do
    ls:add_child(fn(list[i], i))
  end
  return ls
end
