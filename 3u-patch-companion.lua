local event_codes = require "hid_events"
local pfuncs = include('lib/pfuncs')

-- allows having a param that maps to params, to have a param for what param the keys and encoders control
local this_params = {}

-- these clock params just expose relevant clock params next to the other params
local clock_bpm = {
  id="clock_bpm",
  name="clock bpm",
  type="number",
  min=1,
  max=300,
  default=params:get("clock_tempo"),
  action=function(x) params:set("clock_tempo", x) end
}
this_params[clock_bpm.id] = clock_bpm
params:add(clock_bpm)

local crow_clock_output_3 = {
  id="crow_clock_output_3",
  name="crow clock out 3",
  type="binary",
  behavior="toggle",
  default=1,
  action=function(x)
    if x == 1 then
      params:set("clock_crow_out", 4) -- "output 3"
    else
      params:set("clock_crow_out", 1) -- "off"
      -- pfuncs.clear_ii_voices()
    end
  end
}
this_params[crow_clock_output_3.id] = crow_clock_output_3
params:add(crow_clock_output_3)

-- controls the builtin CLOCK>crow>crow out div param, but by multiplying/dividing by 2 instead of incrementing by one
local crow_clock_div_x2 = {
  id="crow_clock_div_x2",
  name="crow clock div x2",
  type="number",
  min=1,
  max=32,
  default=params:get("clock_crow_out_div"),
  formatter=function(param)
    local div = params:get("clock_crow_out_div")
    params:set("crow_clock_div_x2", div)
    return div
  end,
  action=function(x)
    local div = params:get("clock_crow_out_div")
    -- decrease
    if x < div then
      div = math.floor(div/2)
      div = math.max(1, math.min(32, div))
      params:set("clock_crow_out_div", div)
      params:set("crow_clock_div_x2", div)
    elseif x > div then -- increase
      div = div*2
      div = math.max(1, math.min(32, div))
      params:set("clock_crow_out_div", div)
      params:set("crow_clock_div_x2", div)
    end
  end
}
this_params[crow_clock_div_x2.id] = crow_clock_div_x2
params:add(crow_clock_div_x2)

local reset_ansible = {
  id="reset_ansible",
  name="reset ansible",
  type="binary",
  behavior="trigger",
  action=function(x)
    -- crow.output[2].volts = 5
    -- crow.output[2].volts = 0
    crow.ii.txo.tr_pulse(4)
  end
}
this_params[reset_ansible.id] = reset_ansible
params:add(reset_ansible)

local wsyn_curve = {
  id="wsyn_curve",
  name="wsyn curve",
  type="control",
  controlspec=controlspec.def{
        min = -5.0,
        max = 5.0,
        warp = 'lin',
        step = 0.01,
        default = 5,
        units = 'v',
        quantum = 0.005,
        wrap = false
    },
  formatter=function(param) return string.format("%.2f", param:get()) end,
  action=function(x) crow.ii.wsyn.curve(x) end
}
this_params[wsyn_curve.id] = wsyn_curve
params:add(wsyn_curve)

local wsyn_ramp = {
  id="wsyn_ramp",
  name="wsyn ramp",
  type="control",
  controlspec=controlspec.def{
        min = -5.0,
        max = 5.0,
        warp = 'lin',
        step = 0.01,
        default = 0,
        units = 'v',
        quantum = 0.005,
        wrap = false
    },
  formatter=function(param) return string.format("%.2f", param:get()) end,
  action=function(x) crow.ii.wsyn.ramp(x) end
}
this_params[wsyn_ramp.id] = wsyn_ramp
params:add(wsyn_ramp)

local wsyn_fm_index = {
  id="wsyn_fm_index",
  name="wsyn fm index",
  type="control",
  controlspec=controlspec.def{
        min = 0,
        max = 4.0,
        warp = 'lin',
        step = 0.01,
        default = 0,
        units = 'v',
        -- quantum = 0.01,
        quantum = 0.0002,
        wrap = false
    },
  formatter=function(param) return string.format("%.2f", param:get()) end,
  action=function(x)
    crow.ii.wsyn.fm_index(x)
    -- patch cv output 4 to the cv in of the veils channel wsyn goes through
    -- veils slider at max, offset min, linear response
    -- closes vca as more fm applied to compensate for perceived volume increase
    local cv = 8 - (x / 4) * 3
    crow.output[4].volts = cv
    -- print("fm index: "..x..", cv: "..cv)
  end
}
this_params[wsyn_fm_index.id] = wsyn_fm_index
params:add(wsyn_fm_index)

-- params:add{
--   id="wsyn vca level",
--   type="control",
--     controlspec=controlspec.def{
--         min = 0,
--         max = 4.0,
--         warp = 'lin',
--         step = 0.01,
--         default = 0,
--         units = 'v',
--         -- quantum = 0.01,
--         quantum = 0.0002,
--         wrap = false
--     },
-- }
-- -- should be hidden from menu, only controlled by script
-- params:hide("wsyn vca level")
-- _menu.rebuild_params()
local wsyn_fm_env = {
  id="wsyn_fm_env",
  name="wsyn fm env",
  type="control",
  controlspec=controlspec.def{
        min = -5,
        max = 5,
        warp = 'lin',
        step = 0.01,
        default = 0,
        units = 'v',
        quantum = 0.005,
        wrap = false
    },
  formatter=function(param) return string.format("%.2f", param:get()) end,
  action=function(x) crow.ii.wsyn.fm_env(x) end
}
this_params[wsyn_fm_env.id] = wsyn_fm_env
params:add(wsyn_fm_env)

local wsyn_fm_ratio = {
  id="wsyn_fm_ratio",
  name="wsyn fm ratio",
  type="number",
  min=1,
  max=24,
  default=4,
  action=function(x) crow.ii.wsyn.fm_ratio(x) end
}
this_params[wsyn_fm_ratio.id] = wsyn_fm_ratio
params:add(wsyn_fm_ratio)

local wsyn_lpg_symmetry = {
  id="wsyn_lpg_symmetry",
  name="wsyn lpg symmetry",
  type="control",
  controlspec=controlspec.def{
        min = -5,
        max = 5,
        warp = 'lin',
        step = 0.01,
        default = -3.5,
        units = 'v',
        quantum = 0.005,
        wrap = false
    },
  formatter=function(param) return string.format("%.2f", param:get()) end,
  action=function(x) crow.ii.wsyn.lpg_symmetry(x) end
}
this_params[wsyn_lpg_symmetry.id] = wsyn_lpg_symmetry
params:add(wsyn_lpg_symmetry)

local wsyn_lpg_time = {
  id="wsyn_lpg_time",
  name="wsyn lpg time",
  type="control",
  controlspec=controlspec.def{
        min = -4,
        max = 4,
        warp = 'lin',
        step = 0.01,
        default = -2.7,
        units = 'v',
        quantum = 0.0002,
        wrap = false
    },
  formatter=function(param) return string.format("%.2f", param:get()) end,
  action=function(x) crow.ii.wsyn.lpg_time(x) end
}
this_params[wsyn_lpg_time.id] = wsyn_lpg_time
params:add(wsyn_lpg_time)

local txo_waveshape_voice_3 = {
  id="txo_waveshape_voice_3",
  name="txo waveshape - voice 3",
  type="number",
  min=0,
  max=4500,
  default=0,
  action=function(x) crow.ii.txo.osc_wave(3, x) end
}
this_params[txo_waveshape_voice_3.id] = txo_waveshape_voice_3
params:add(txo_waveshape_voice_3)

local txo_level_voice_3 = {
  id="txo_level_voice_3",
  name="txo level - voice 3",
  type="control",
  controlspec=controlspec.def{
        min = 0,
        max = 8,
        warp = 'lin',
        step = 0.01,
        default = 1,
        units = 'v',
        quantum = 0.01/8,
        wrap = false
    },
  formatter=function(param) return string.format("%.2f", param:get()) end,
  action=function(x) crow.ii.txo.cv(3, x) end
}
this_params[txo_level_voice_3.id] = txo_level_voice_3
params:add(txo_level_voice_3)

local txo_attack_voice_3 = {
  id="txo_attack_voice_3",
  name="txo attack - voice 3",
  type="control",
  controlspec=controlspec.def{
        min = 1,
        max = 5000,
        warp = 'exp',
        step = 1,
        default = 40,
        units = 'mv',
        quantum = 0.002,
        wrap = false
    },
  -- formatter=function(param) return param:get() end,
  action=function(x) crow.ii.txo.env_att(3, x) end
}
this_params[txo_attack_voice_3.id] = txo_attack_voice_3
params:add(txo_attack_voice_3)

-- local txo_decay_voice_3 = {
--   id="txo_decay_voice_3",
--   name="txo decay - voice 3",
--   type="number",
--   min=0,
--   max=10000,
--   default=2000,
--   action=function(x) crow.ii.txo.env_dec(3, x) end
-- }
local txo_decay_voice_3 = {
  id="txo_decay_voice_3",
  name="txo decay - voice 3",
  type="control",
  controlspec=controlspec.def{
        min = 1,
        max = 10000,
        warp = 'exp',
        step = 1,
        default = 2000,
        units = 'mv',
        quantum = 0.002,
        wrap = false
    },
  -- formatter=function(param) return param:get() end,
  action=function(x) crow.ii.txo.env_dec(3, x) end
}
this_params[txo_decay_voice_3.id] = txo_decay_voice_3
params:add(txo_decay_voice_3)

local txo_waveshape_voice_4 = {
  id="txo_waveshape_voice_4",
  name="txo waveshape - voice 4",
  type="number",
  min=0,
  max=4500,
  default=0,
  action=function(x) crow.ii.txo.osc_wave(4, x) end
}
this_params[txo_waveshape_voice_4.id] = txo_waveshape_voice_4
params:add(txo_waveshape_voice_4)

local txo_attack_voice_4 = {
  id="txo_attack_voice_4",
  name="txo attack - voice 4",
  type="number",
  min=0,
  max=5000,
  default=40,
  action=function(x) crow.ii.txo.env_att(4, x) end
}
this_params[txo_attack_voice_4.id] = txo_attack_voice_4
params:add(txo_attack_voice_4)

local txo_decay_voice_4 = {
  id="txo_decay_voice_4",
  name="txo decay - voice 4",
  type="number",
  min=0,
  max=10000,
  default=1000,
  action=function(x) crow.ii.txo.env_dec(4, x) end
}
this_params[txo_decay_voice_4.id] = txo_decay_voice_4
params:add(txo_decay_voice_4)
local crow_ins_to_wsyn = {
  id="crow_ins_to_wsyn",
  name="crow ins to wsyn",
  type="binary",
  behavior="toggle",
  default=0,
  action=function(x)
    if x == 1 then
      pfuncs.crow_ins_to_wsyn_start()
    else
      pfuncs.crow_ins_to_wsyn_stop()
    end
  end
}
this_params[crow_ins_to_wsyn.id] = crow_ins_to_wsyn
params:add(crow_ins_to_wsyn)

-- create key and encoder action params
local key_options = {}
local key_option_to_id = {}
local enc_options = {}
local enc_option_to_id = {}
for _,p in pairs(this_params) do
  if p.type == "binary" then
    table.insert(key_options, p.name)
    key_option_to_id[p.name] = p.id
  elseif p.type == "number" or p.type == "control" then
    table.insert(enc_options, p.name)
    enc_option_to_id[p.name] = p.id
  end
end

local k2_action = {
    id="k2_action",
    name="k2 action",
    type="option",
    options=key_options,
    default = pfuncs.get_index_of_value(key_options, "crow clock out 3"),
    action=function(p)
    end
}
this_params[k2_action.id] = k2_action
params:add(k2_action)

local k3_action = {
    id="k3_action",
    name="k3 action",
    type="option",
    options=key_options,
    default = pfuncs.get_index_of_value(key_options, "reset ansible"),
    action=function(p)
    end
}
this_params[k3_action.id] = k3_action
params:add(k3_action)

local e1_action = {
    id="e1_action",
    name="e1 action",
    type="option",
    options=enc_options,
    default = pfuncs.get_index_of_value(enc_options, "clock bpm"),
    action=function(p)
    end
}
this_params[e1_action.id] = e1_action
params:add(e1_action)

local e2_action = {
    id="e2_action",
    name="e2 action",
    type="option",
    options=enc_options,
    default = pfuncs.get_index_of_value(enc_options, "txo attack - voice 3"),
    action=function(p)
    end
}
this_params[e2_action.id] = e2_action
params:add(e2_action)

local e3_action = {
    id="e3_action",
    name="e3 action",
    type="option",
    options=enc_options,
    default = pfuncs.get_index_of_value(enc_options, "txo decay - voice 3"),
    action=function(p)
    end
}
this_params[e3_action.id] = e3_action
params:add(e3_action)

params:default()
params:bang()

function key(n, z)
  local id = key_option_to_id[key_options[params:get("k"..n.."_action")]]
  local behavior = this_params[id].behavior
  if behavior == "toggle" and z == 1 then
    params:set(id, 1 - params:get(id))
  elseif behavior == "trigger" and z == 1 then
    params:set(id, 1)
  elseif behavior == "momentary" then
    params:set(id, z)
  end
end

function enc(n, d)
  local id = enc_option_to_id[enc_options[params:get("e"..n.."_action")]]
  params:delta(id, d)
end

function trackball_input(typ, code, val)
  local p
  -- hid_events.codes.REL_X = 0x00
  if code == 0x00 then
    p = "wsyn_fm_index"
  -- hid_events.codes.REL_Y = 0x01
  elseif code == 0x01 then
    p = "wsyn_lpg_time"
  -- hid_events.codes.REL_WHEEL = 0x08
  elseif code == 0x08 then
    p = "wsyn_fm_ratio"
    val = -val
  end

  if p then
    params:delta(p, val)
    -- print("delta: "..val.." "..p..": "..params:get(p))
  end

end
hid.vports[1].event = trackball_input
