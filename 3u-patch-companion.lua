-- -- crow.ii.wsyn.ar_mode(1)
-- crow.ii.wsyn.curve(5)
-- crow.ii.wsyn.ramp(0)
-- crow.ii.wsyn.fm_index(0)
-- -- crow.ii.wsyn.fm_env(-.35) -- this offsets the minimum CV that comes out of planar
-- -- crow.ii.wsyn.fm_env(-.5) -- this offsets the minimum CV that comes out of planar when attenuated by a mystic 0tennuator at noon
-- crow.ii.wsyn.fm_env(0)
-- crow.ii.wsyn.fm_ratio(4)
-- crow.ii.wsyn.lpg_symmetry(-3.5)
-- crow.ii.wsyn.lpg_time(-2.73)
-- -- crow.ii.wsyn.patch(1, 3) -- this to fm env, use planar unipolar out
-- -- crow.ii.wsyn.patch(2, 5) -- that to lpg time
-- -- mappings = {
-- --     crow.ii.wsyn.fm_env,
-- --     crow.ii.wsyn.lpg_time
-- -- }

-- function initTxo()
--     clock.sleep(1)
--     crow.ii.txo.cv(3, 1)
--     crow.ii.txo.osc_wave(3, 0)
--     crow.ii.txo.env_att(3, 50)
--     crow.ii.txo.env_dec(3, 400)
-- end

-- clock.run(initTxo)

local event_codes = require "hid_events"
local pfuncs = include('lib/pfuncs')

local key_param_options = {
  ids = {
    "crow_clock_output_3",
    "crow_trigger_output_2"
  },
  names = {
    "crow clock",
    "reset ansible"
  }
}
local enc_param_options = {
  ids = {

  },
  names = {

  }
}

-- these clock params just expose relevant clock params next to the other params
local this_params = {}
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
    end
  end
}
this_params[crow_clock_output_3.id] = crow_clock_output_3
params:add(crow_clock_output_3)
local crow_trigger_output_2 = {
  id="crow_trigger_output_2",
  name="reset ansible",
  type="binary",
  behavior="trigger",
  action=function(x)
    crow.output[2].volts = 5
    crow.output[2].volts = 0
  end
}
this_params[crow_trigger_output_2.id] = crow_trigger_output_2
params:add(crow_trigger_output_2)
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
  type="number",
  min=0,
  max=5000,
  default=40,
  action=function(x) crow.ii.txo.env_att(3, x) end
}
this_params[txo_attack_voice_3.id] = txo_attack_voice_3
params:add(txo_attack_voice_3)
local txo_decay_voice_3 = {
  id="txo_decay_voice_3",
  name="txo decay - voice 3",
  type="number",
  min=0,
  max=10000,
  default=2000,
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

local key_2_action = {
    id="key_2_action",
    name="key 2 action",
    type="option",
    options=key_options,
    default = pfuncs.get_index_of_value(key_options, "crow clock out 3"),
    action=function(p)
    end
}
this_params[key_2_action.id] = key_2_action
params:add(key_2_action)

local key_3_action = {
    id="key_3_action",
    name="key 3 action",
    type="option",
    options=key_options,
    default = pfuncs.get_index_of_value(key_options, "reset ansible"),
    action=function(p)
    end
}
this_params[key_3_action.id] = key_3_action
params:add(key_3_action)

local enc_1_action = {
    id="enc_1_action",
    name="enc 1 action",
    type="option",
    options=enc_options,
    default = pfuncs.get_index_of_value(enc_options, "clock bpm"),
    action=function(p)
    end
}
this_params[enc_1_action.id] = enc_1_action
params:add(enc_1_action)

local enc_2_action = {
    id="enc_2_action",
    name="enc 2 action",
    type="option",
    options=enc_options,
    default = pfuncs.get_index_of_value(enc_options, "txo attack - voice 3"),
    action=function(p)
    end
}
this_params[enc_2_action.id] = enc_2_action
params:add(enc_2_action)

local enc_3_action = {
    id="enc_3_action",
    name="enc 3 action",
    type="option",
    options=enc_options,
    default = pfuncs.get_index_of_value(enc_options, "txo decay - voice 3"),
    action=function(p)
    end
}
this_params[enc_3_action.id] = enc_3_action
params:add(enc_3_action)

function key(n, z)
  local id = key_option_to_id[key_options[params:get("key_"..n.."_action")]]
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
  local id = enc_option_to_id[enc_options[params:get("enc_"..n.."_action")]]
  params:delta(id, d)
end

-- for _,p in pairs(this_params) do
--   params:add(p)
-- end
params:default()
params:bang()

function trackball_input(typ, code, val)
  local p
  -- hid_events.codes.REL_X = 0x00
  if code == 0x00 then
    p = "wsyn fm index"
  -- hid_events.codes.REL_Y = 0x01
  elseif code == 0x01 then
    p = "wsyn lpg time"
  -- hid_events.codes.REL_WHEEL = 0x08
  elseif code == 0x08 then
    p = "wsyn fm ratio"
    val = -val
  end

  if p then
    params:delta(p, val)
    -- print("delta: "..val.." "..p..": "..params:get(p))
  end

end
hid.vports[1].event = trackball_input

-- function clock_crow()
--   clock.sync(1/4)
-- end

