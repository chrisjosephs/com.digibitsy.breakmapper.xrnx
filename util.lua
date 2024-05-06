function table:map(ts, f)
  local ls = {}
  local i = 1
  for k, x in pairs(ts) do
    table.insert(ls, f(x, i))
    i = i + 1
  end
  return ls
end

function table:shuffle(t)
  local shuffled = {}
  for i, v in ipairs(t) do
    local pos = math.random(1, #shuffled+1)
    table.insert(shuffled, pos, v)
  end
  return shuffled
end

function ifelse(c, a, b)
  if c then return a else return b end
end

math.round = function(x)
  return math.ceil(x - 0.5)
end

function table:swap(t, a, b)
  t[a], t[b] = t[b], t[a]
  return t
end

function table:reverse(ts)
  local t = {}
  for i = #ts, 1, -1 do
    t[#t+1] = ts[i]
  end
  return t
end

function table:find(t, f)
  for i = 1, #t do
    if f(t[i]) then 
      return t[i]
    end
  end
  return nil
end

function table:find_index(t, f)
  for i = 1, #t do
    if f(t[i]) then 
      return i
    end
  end
  return 0
end

function clamp(a, min, max)
  return math.min(math.max(min, a), max)
end


function prop_with_value_exist_in_table(prop, target_value, tabl)
  return table:find(tabl, function(v) return v[prop] == target_value end) ~= nil
end

function enable_notifier(base, target, fun)
  if not base[target .. "_observable"]:has_notifier(fun) then
    base[target .. "_observable"]:add_notifier(fun)
  end
end

DASHED_NOTE_NAMES = {
  "C-", "C#","D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"
}

NOTE_NAMES = {
  "C", "C#","D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"
}

OCTAVES = {
  "0","1","2","3","4","5","6","7","8","9"
}