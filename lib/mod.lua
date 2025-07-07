local mod = require 'core/mods'

mod.hook.register("script_pre_init", "3u patch companion pre init", function()
  local pfuncs = include('3u-patch-companion/lib/pfuncs')

  -- allows having a param that maps to params, to have a param for what param the keys and encoders control
  params_3u_patch = {}

  -- paste the following into kakoune prompt to get number of params
  -- actually doesn't work anymore since i'm creating some params programmatically
  -- exec \%sparams:add\(<ret>:echo<space>%val{selection_count}<ret>
  params:add_group("3u_patch_params", "3U PATCH", 46)
  -- local group_3u = group.new("3u_patch_params", "3U PATCH", 35)

  local reset_ansible = {
    id="reset_ansible",
    name="reset ansible",
    type="binary",
    behavior="trigger",
    action=function(x)
      crow.ii.txo.tr_pulse(2)
    end
  }
  -- params_3u_patch[reset_ansible.id] = reset_ansible
  table.insert(params_3u_patch, reset_ansible)
  params:add(reset_ansible)

  local bang_params = {
    id="bang_params",
    name="bang",
    type="binary",
    behavior="trigger",
    action=function() params:bang() end
  }
  -- params_3u_patch[bang_params.id] = bang_params
  -- table.insert(params_3u_patch, bang_params)
  params:add(bang_params)

  function update_txo_clocks()
    for i=1,4 do
      local base_id = "clock_txo_tr_"..i
      if params:get(base_id) == 1 then
        crow.ii.txo.tr_m(i, clock.get_beat_sec() * 1000 / params:get(base_id.."_div"))
      end
    end
  end

  -- these clock params just expose relevant clock params next to the other params
  local clock_bpm = {
    id="clock_bpm",
    name="clock bpm",
    type="number",
    min=1,
    max=300,
    default=params:get("clock_tempo"),
    action=function(x)
      params:set("clock_tempo", x)
      update_txo_clocks()
    end
  }
  -- params_3u_patch[clock_bpm.id] = clock_bpm
  table.insert(params_3u_patch, clock_bpm)
  params:add(clock_bpm)

  function make_txo_m_toggle_func(port)
    return function(z)
      local base_id = "clock_txo_tr_"..port
      local base_name = "clock txo "..port

      if z == 1 then
        -- crow.ii.txo.tr_time(3, 60/(2*clock.get_tempo()*params:get("clock_txo_3_div"))*1000)
        crow.ii.txo.tr_time(port, 10)
        crow.ii.txo.tr_m(port, clock.get_beat_sec() * 1000 / params:get(base_id.."_div"))
        crow.ii.txo.tr_m_act(port, 1)
        if (not clock_txo_m_id) then
          clock_txo_m_id = clock.run(function()
            while true do
              clock.sync(1)
              crow.ii.txo.m_sync(1)
            end
          end)
        end

        params:lookup_param(base_id).name = "● "..base_name
        params:show(base_id.."_div")
        params:show(base_id.."_div_x2")
        _menu.rebuild_params()
      else
        crow.ii.txo.tr_m_act(port, 0)
        if (clock_txo_m_id and
          params:get("clock_txo_tr_1") == 0 and
          params:get("clock_txo_tr_2") == 0 and
          params:get("clock_txo_tr_3") == 0 and
          params:get("clock_txo_tr_4") == 0) then
          clock.cancel(clock_txo_m_id)
          clock_txo_m_id = nil
        end

        params:lookup_param(base_id).name = "○ "..base_name
        params:hide(base_id.."_div")
        params:hide(base_id.."_div_x2")
        _menu.rebuild_params()
      end
    end
  end

  function make_txo_m_div_func(port)
    return function(div)
      crow.ii.txo.tr_m(port, clock.get_beat_sec() * 1000 / div)
    end
  end

  for i=1,4 do
    local base_id = "clock_txo_tr_"..i
    local div_id = base_id.."_div"
    local base_name = "clock txo "..i

    local base_param = {
      id=base_id,
      name="○ "..base_name,
      type="binary",
      behavior="toggle",
      default=0,
      action=make_txo_m_toggle_func(i)
    }
    if i == 3 or i == 4 then
      base_param.default = 1
    end
    table.insert(params_3u_patch, base_param)
    params:add(base_param)

    div_param = {
      id=base_id.."_div",
      name=base_name.." div",
      type="number",
      min=1,
      max=32,
      default=16,
      action=make_txo_m_div_func(i)
    }
    table.insert(params_3u_patch, div_param)
    params:add(div_param)
    if params:get(base_id) == 0 then
        params:hide(base_id.."_div")
        _menu.rebuild_params()
    end

    div_x2_param = {
      id=div_id.."_x2",
      name=base_name.." div x2",
      type="number",
      min=1,
      max=32,
      default=params:get(div_id),
      formatter=function(val)
        local div = params:get(div_id)
        params:set(div_id.."_x2", div)
        return div
      end,
      action=function(x)
        local div = params:get(div_id)
        -- decrease
        if x < div then
          div = math.floor(div/2)
          div = math.max(1, math.min(32, div))
          params:set(div_id, div)
          params:set(div_id.."_x2", div)
        elseif x > div then -- increase
          div = div*2
          div = math.max(1, math.min(32, div))
          params:set(div_id, div)
          params:set(div_id.."_x2", div)
        end
      end
    }

    table.insert(params_3u_patch, div_x2_param)
    params:add(div_x2_param)
    if params:get(base_id) == 0 then
      params:hide(base_id.."_div")
      _menu.rebuild_params()
    end
  end

  local txo_cv_3_oct = {
    id="txo_cv_3_oct",
    name="txo cv 3 oct",
    type="number",
    min=-5,
    max=5,
    default=0,
    action=function(x)
      crow.ii.txo.cv_n(3, 12 * x)
    end
  }
  table.insert(params_3u_patch, txo_cv_3_oct)
  params:add(txo_cv_3_oct)

  local crow_clock_output_3 = {
    id="crow_clock_output_3",
    name="crow clock out 3",
    type="binary",
    behavior="toggle",
    default=0,
    action=function(x)
      if x == 1 then
        params:set("clock_crow_out", 4) -- "output 3"
      else
        params:set("clock_crow_out", 1) -- "off"
        -- pfuncs.clear_ii_voices()
      end
    end
  }
  -- params_3u_patch[crow_clock_output_3.id] = crow_clock_output_3
  table.insert(params_3u_patch, crow_clock_output_3)
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
  -- params_3u_patch[crow_clock_div_x2.id] = crow_clock_div_x2
  table.insert(params_3u_patch, crow_clock_div_x2)
  params:add(crow_clock_div_x2)

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
  -- params_3u_patch[wsyn_curve.id] = wsyn_curve
  table.insert(params_3u_patch, wsyn_curve)
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
  -- params_3u_patch[wsyn_ramp.id] = wsyn_ramp
  table.insert(params_3u_patch, wsyn_ramp)
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
  -- params_3u_patch[wsyn_fm_index.id] = wsyn_fm_index
  table.insert(params_3u_patch, wsyn_fm_index)
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
  -- params_3u_patch[wsyn_fm_env.id] = wsyn_fm_env
  table.insert(params_3u_patch, wsyn_fm_env)
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
  -- params_3u_patch[wsyn_fm_ratio.id] = wsyn_fm_ratio
  table.insert(params_3u_patch, wsyn_fm_ratio)
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
  -- params_3u_patch[wsyn_lpg_symmetry.id] = wsyn_lpg_symmetry
  table.insert(params_3u_patch, wsyn_lpg_symmetry)
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
  -- params_3u_patch[wsyn_lpg_time.id] = wsyn_lpg_time
  table.insert(params_3u_patch, wsyn_lpg_time)
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
  -- params_3u_patch[txo_waveshape_voice_3.id] = txo_waveshape_voice_3
  table.insert(params_3u_patch, txo_waveshape_voice_3)
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
  -- params_3u_patch[txo_level_voice_3.id] = txo_level_voice_3
  table.insert(params_3u_patch, txo_level_voice_3)
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
  -- params_3u_patch[txo_attack_voice_3.id] = txo_attack_voice_3
  table.insert(params_3u_patch, txo_attack_voice_3)
  params:add(txo_attack_voice_3)

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
  -- params_3u_patch[txo_decay_voice_3.id] = txo_decay_voice_3
  table.insert(params_3u_patch, txo_decay_voice_3)
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
  -- params_3u_patch[txo_waveshape_voice_4.id] = txo_waveshape_voice_4
  table.insert(params_3u_patch, txo_waveshape_voice_4)
  params:add(txo_waveshape_voice_4)

  local txo_level_voice_4 = {
    id="txo_level_voice_4",
    name="txo level - voice 4",
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
    action=function(x) crow.ii.txo.cv(4, x) end
  }
  -- params_3u_patch[txo_level_voice_4.id] = txo_level_voice_4
  table.insert(params_3u_patch, txo_level_voice_4)
  params:add(txo_level_voice_4)

  local txo_attack_voice_4 = {
    id="txo_attack_voice_4",
    name="txo attack - voice 4",
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
    action=function(x) crow.ii.txo.env_att(4, x) end
  }
  -- params_3u_patch[txo_attack_voice_4.id] = txo_attack_voice_4
  table.insert(params_3u_patch, txo_attack_voice_4)
  params:add(txo_attack_voice_4)

  local txo_decay_voice_4 = {
    id="txo_decay_voice_4",
    name="txo decay - voice 4",
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
    action=function(x) crow.ii.txo.env_dec(4, x) end
  }
  -- params_3u_patch[txo_decay_voice_4.id] = txo_decay_voice_4
  table.insert(params_3u_patch, txo_decay_voice_4)
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
  -- params_3u_patch[crow_ins_to_wsyn.id] = crow_ins_to_wsyn
  table.insert(params_3u_patch, crow_ins_to_wsyn)
  params:add(crow_ins_to_wsyn)

  -- allows keys and encoders to be mapped to nothing
  local empty_param = {
    id="empty_param",
    name="none",
    type="number",
  }
  -- params_3u_patch[empty_param.id] = empty_param
  table.insert(params_3u_patch, empty_param)
  params:add(empty_param)
  params:hide(empty_param.id)
  _menu.rebuild_params()

  -- create key and encoder action params
  key_options = {}
  key_option_to_id = {}
  enc_options = {}
  enc_option_to_id = {}
  trackball_options = {}
  trackball_option_to_id = {}

  table.insert(key_options, "none")
  key_option_to_id["none"] = "empty_param"
  -- table.insert(enc_options, "none")
  -- enc_option_to_id["none"] = "empty_param"
  -- table.insert(trackball_options, "none")
  -- trackball_option_to_id["none"] = "empty_param"

  for i,p in ipairs(params_3u_patch) do
    if p.type == "binary" then
      table.insert(key_options, p.name)
      key_option_to_id[p.name] = p.id
    elseif p.type == "number" or p.type == "control" then
      table.insert(enc_options, p.name)
      enc_option_to_id[p.name] = p.id
      table.insert(trackball_options, p.name)
      trackball_option_to_id[p.name] = p.id
    end
  end

  local trackball_x_action = {
    id="trackball_x_action",
    name="ball x",
    type="option",
    options=trackball_options,
    default = pfuncs.get_index_of_value(trackball_options, "wsyn fm index"),
  }
  -- params_3u_patch[trackball_x_action.id] = trackball_x_action
  table.insert(params_3u_patch, trackball_x_action)
  params:add(trackball_x_action)

  local trackball_y_action = {
    id="trackball_y_action",
    name="ball y",
    type="option",
    options=trackball_options,
    default = pfuncs.get_index_of_value(trackball_options, "wsyn lpg time"),
  }
  -- params_3u_patch[trackball_y_action.id] = trackball_y_action
  table.insert(params_3u_patch, trackball_y_action)
  params:add(trackball_y_action)

  local trackball_scroll_action = {
    id="trackball_scroll_action",
    name="ball scroll",
    type="option",
    options=trackball_options,
    default = pfuncs.get_index_of_value(trackball_options, "wsyn fm ratio"),
  }
  -- params_3u_patch[trackball_scroll_action.id] = trackball_scroll_action
  table.insert(params_3u_patch, trackball_scroll_action)
  params:add(trackball_scroll_action)

  local trackball_x_invert = {
    id="trackball_x_invert",
    name="invert ball x",
    type="binary",
    behavior="toggle",
    default = 0,
  }
  -- params_3u_patch[trackball_x_invert.id] = trackball_x_invert
  table.insert(params_3u_patch, trackball_x_invert)
  params:add(trackball_x_invert)

  local trackball_y_invert = {
    id="trackball_y_invert",
    name="invert ball y",
    type="binary",
    behavior="toggle",
    default = 0,
  }
  -- params_3u_patch[trackball_y_invert.id] = trackball_y_invert
  table.insert(params_3u_patch, trackball_y_invert)
  params:add(trackball_y_invert)

  local trackball_scroll_invert = {
    id="trackball_scroll_invert",
    name="invert ball scroll",
    type="binary",
    behavior="toggle",
    default = 1,
  }
  -- params_3u_patch[trackball_scroll_invert.id] = trackball_scroll_invert
  table.insert(params_3u_patch, trackball_scroll_invert)
  params:add(trackball_scroll_invert)

  local k2_action = {
    id="k2_action",
    name="k2",
    type="option",
    options=key_options,
    default = pfuncs.get_index_of_value(key_options, "none"),
  }
  -- params_3u_patch[k2_action.id] = k2_action
  table.insert(params_3u_patch, k2_action)
  params:add(k2_action)

  local k3_action = {
    id="k3_action",
    name="k3",
    type="option",
    options=key_options,
    default = pfuncs.get_index_of_value(key_options, "none"),
  }
  -- params_3u_patch[k3_action.id] = k3_action
  table.insert(params_3u_patch, k3_action)
  params:add(k3_action)

  local e1_action = {
    id="e1_action",
    name="e1",
    type="option",
    options=enc_options,
    default = pfuncs.get_index_of_value(enc_options, "none"),
  }
  -- params_3u_patch[e1_action.id] = e1_action
  table.insert(params_3u_patch, e1_action)
  params:add(e1_action)

  local e2_action = {
    id="e2_action",
    name="e2",
    type="option",
    options=enc_options,
    default = pfuncs.get_index_of_value(enc_options, "none"),
  }
  -- params_3u_patch[e2_action.id] = e2_action
  table.insert(params_3u_patch, e2_action)
  params:add(e2_action)

  local e3_action = {
    id="e3_action",
    name="e3",
    type="option",
    options=enc_options,
    default = pfuncs.get_index_of_value(enc_options, "none"),
  }
  -- params_3u_patch[e3_action.id] = e3_action
  table.insert(params_3u_patch, e3_action)
  params:add(e3_action)

  params:default()
  params:bang()
end)

mod.hook.register("script_post_init", "3u patch companion post init", function()
  redraw_capture_metro = metro.init(function()
    if _menu.mode == true then
      return
    elseif _menu.mode == false then
      _script_redraw = redraw
      metro.free(redraw_capture_metro.id)
    else
      print("_menu.mode behavior has changed, mod unable to wrap script's redraw function")
    end
  end, 1/10)
  redraw_capture_metro:start()

  key_wrapped = key
  function key(n, z)
    local id = key_option_to_id[key_options[params:get("k"..n.."_action")]]
    if (id ~= 'empty_param') then
      local behavior = params:lookup_param(id).behavior
      if behavior == "toggle" and z == 1 then
        params:set(id, 1 - params:get(id))
      elseif behavior == "trigger" and z == 1 then
        params:set(id, 1)
      elseif behavior == "momentary" then
        params:set(id, z)
      end
    end

    key_wrapped(n, z)
  end

  enc_wrapped = enc
  function enc(n, delta)
    local id = enc_option_to_id[enc_options[params:get("e"..n.."_action")]]
    params:delta(id, delta)

    enc_wrapped(n, delta)
  end

  function trackball_input(typ, code, val)
    local param_id
    if code == 0x00 then -- hid_events.codes.REL_X = 0x00
      param_id = trackball_option_to_id[trackball_options[params:get("trackball_x_action")]]
      if (params:get("trackball_x_invert") == 1) then
        val = -val
      end
    elseif code == 0x01 then -- hid_events.codes.REL_Y = 0x01
      param_id = trackball_option_to_id[trackball_options[params:get("trackball_y_action")]]
      if (params:get("trackball_y_invert") == 1) then
        val = -val
      end
    elseif code == 0x08 then -- hid_events.codes.REL_WHEEL = 0x08
      param_id = trackball_option_to_id[trackball_options[params:get("trackball_scroll_action")]]
      if (params:get("trackball_scroll_invert") == 1) then
        val = -val
      end
    end

    if (param_id) then
      params:delta(param_id, val)
    end
  end

  for i,device in pairs(hid.vports) do
    if (device.name == "Kensington SlimBlade Pro Trackball(Wired)") then
      device.event = trackball_input
    end
  end
end)

