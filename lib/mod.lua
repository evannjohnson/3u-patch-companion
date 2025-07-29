local mod = require 'core/mods'

function darken_buffer(buf, level)
  level = level or 1
  local t = {}
  for i = 1, #buf do
      local byte = buf:byte(i) - level
      t[i] = string.char(byte < 0 and 0 or byte)
  end
  return table.concat(t)
end

mod.hook.register("script_pre_init", "3u patch companion pre init", function()
  local pfuncs = include('3u-patch-companion/lib/pfuncs')

  -- allows having a param that maps to params, to have a param for what param the keys and encoders control
  mappable_params_3u = {}

  -- paste the following into kakoune prompt to get number of params
  -- doesn't work anymore since i'm creating some params programmatically
  -- exec \%sparams:add\(<ret>:echo<space>%val{selection_count}<ret>
  params:add_group("3u_patch_params", "3U PATCH", 75)

  -- allows keys and encoders to be mapped to nothing
  local empty_param = {
    id="empty_param_3u",
    name="none",
    type="number",
    min=0,
    max=0
  }
  table.insert(mappable_params_3u, empty_param)
  params:add(empty_param)
  params:hide(empty_param.id)
  _menu.rebuild_params()

  local reset_ansible = {
    id="reset_ansible",
    name="reset ansible",
    type="binary",
    behavior="trigger",
    action=function(x)
      crow.ii.txo.tr_pulse(2)
    end
  }
  table.insert(mappable_params_3u, reset_ansible)
  params:add(reset_ansible)

  local bang_params = {
    id="bang_params",
    name="bang",
    type="binary",
    behavior="trigger",
    action=function() params:bang() end
  }
  params:add(bang_params)

  function update_txo_clocks(beat_sec)
    for i=1,4 do
      local base_id = "clock_txo_tr_"..i
      if params:get(base_id) == 1 then
        local m = beat_sec * 1000 / params:get(base_id.."_div")
        crow.ii.txo.tr_m(i, m)
      end
    end
  end

  -- clock division at which to sync txo metronome
  -- enables runtime control
  -- for smaller division at lower clock speeds where drift was an issue
  -- integer, bigger = faster, ex. 16 is clock.sync(1/16)
  txo_m_sync_div_3u = 1

  -- these clock params just expose relevant clock params next to the other params
  local clock_bpm = {
    id="clock_bpm",
    name="clock bpm",
    type="control",
    controlspec=controlspec.def{
      min = 1,
      max = 600,
      warp = 'exp',
      step = 0.1,
      default = norns.state.clock.tempo,
      quantum = 0.2/599,
      wrap = false
    },
    formatter=function(param)
      local bpm = param:get()
      return string.format("%.1f ◀ %.1f ▶ %.1f", bpm / 2, bpm, bpm * 2)
    end,
    action=function(x)
      params:set("clock_tempo", x)
      -- must calculate manually because clock.get_beat_sec() doesn't update immediately
      local beat_sec = 60.0 / x
      local sync_sec = clock.get_beat_sec() / txo_m_sync_div_3u
      if sync_sec > 1 then
        txo_m_sync_div_3u = txo_m_sync_div_3u * 2
      elseif sync_sec < 0.5 then
        txo_m_sync_div_3u = txo_m_sync_div_3u / 2
      end
      update_txo_clocks(beat_sec)
    end
  }
  table.insert(mappable_params_3u, clock_bpm)
  params:add(clock_bpm)

  local clock_bpm_x2 = {
    id="clock_bpm_x2",
    name="clock bpm x2",
    type="control",
    controlspec=controlspec.def{
      min = 1,
      max = 600,
      warp = 'lin',
      step = 0.1,
      default = norns.state.clock.tempo,
      quantum = 0.1/599,
      wrap = false
    },
    formatter=function(val)
      local bpm = params:get("clock_tempo")
      params:set("clock_bpm_x2", bpm)
      return bpm
    end,
    action=function(x)
      local bpm = params:get("clock_tempo")
      if x < bpm then
        bpm = bpm / 2
        params:set("clock_bpm", bpm)
        params:set("clock_bpm_x2", bpm)
      elseif x > bpm then -- increase
        bpm = bpm * 2
        params:set("clock_bpm", bpm)
        params:set("clock_bpm_x2", bpm)
      end
    end
  }
  params:add(clock_bpm_x2)

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
              clock.sync(1/txo_m_sync_div_3u)
              -- crow.output[2].volts = 6
              -- crow.output[2].volts = 0
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
    table.insert(mappable_params_3u, base_param)
    params:add(base_param)

    div_param = {
      id=base_id.."_div",
      name=base_name.." div",
      type="number",
      min=1,
      max=128,
      default=16,
      action=make_txo_m_div_func(i)
    }
    table.insert(mappable_params_3u, div_param)
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
      max=128,
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
          div = math.max(1, math.min(128, div))
          params:set(div_id, div)
          params:set(div_id.."_x2", div)
        elseif x > div then -- increase
          div = div*2
          div = math.max(1, math.min(128, div))
          params:set(div_id, div)
          params:set(div_id.."_x2", div)
        end
      end
    }

    table.insert(mappable_params_3u, div_x2_param)
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
    min=-3,
    max=5,
    default=0,
    action=function(x)
      crow.ii.txo.cv_n(3, 12 * x)
    end
  }
  params:add(txo_cv_3_oct)

  local txo_cv_3_oct_delta = {
    id="txo_cv_3_oct_delta",
    name="txo cv 3 oct",
    type="number",
    min=-3,
    max=3,
    default=0,
    action = function(x)
      local txo_cv_3_oct_v = params:get("txo_cv_3_oct")

      if x == 3 and txo_cv_3_oct_v < 5 then
        params:delta("txo_cv_3_oct", 1)
        params:set("txo_cv_3_oct_delta", 0)
        return
      elseif x == -3 and txo_cv_3_oct_v > -5 then
        params:delta("txo_cv_3_oct", -1)
        params:set("txo_cv_3_oct_delta", 0)
        return
      end
      txo_cv_3_oct_v = params:get("txo_cv_3_oct")

      if params:get("draw_changes") == 1 and
      (redraw == _script_redraw or redraw == _mod_redraw) then
        moon_map = {}
        moon_map[-5] = -9
        moon_map[-4] = -7
        moon_map[-3] = -5
        moon_map[-2] = -4
        moon_map[-1] = -2
        moon_map[0] = 0
        moon_map[1] = 2
        moon_map[2] = 4
        moon_map[3] = 5
        moon_map[4] = 7
        moon_map[5] = 9

        -- some alpha values cause strange results with level_a
        moon_alpha_map = {}
        moon_alpha_map[1] = .1
        moon_alpha_map[2] = .2
        moon_alpha_map[3] = .25
        moon_alpha_map[4] = .4
        moon_alpha_map[5] = .5
        moon_alpha_map[6] = .65
        moon_alpha_map[7] = .75
        moon_alpha_map[8] = .8
        moon_alpha_map[9] = .9
        moon_alpha_map[10] = 1
        moon_alpha_map[11] = 1

        moon_loc = {
          x = 110,
          y = 1,
          w = 12
        }

        if moon_metro then
          metro.free(moon_metro.id)
        end
        moon_fade_counter = 0
        moon_metro = metro.init(function()
          if moon_fade_counter > 20 then
            restore_redraw(_script_redraw)
            metro.free(moon_metro.id)
            moon_metro = nil
            params:lookup_param("txo_cv_3_oct_delta").value = 0
            return
          else
            moon_fade_counter = moon_fade_counter + 1
          end
        end, 1/10)
        moon_metro:start()
        moon_fade_alpha = moon_fade_alpha or .5
        -- print("delta "..d)

        redraw = function()
          _script_redraw()

          screen.level(0)
          screen.rect(moon_loc.x-1, moon_loc.y-1, moon_loc.w+2, moon_loc.w + 5)
          screen.fill()

          screen.display_png(_path.code.."3u-patch-companion/pngs/moon"
                            ..tostring(moon_map[txo_cv_3_oct_v])
                            ..".png", moon_loc.x, moon_loc.y)

          screen.level(15)
          local delta = params:get("txo_cv_3_oct_delta")
          if delta == 2 then
            screen.pixel(moon_loc.x + 7, moon_loc.y + 13)
            screen.pixel(moon_loc.x + 10, moon_loc.y + 13)
          elseif delta == 1 then
            screen.pixel(moon_loc.x + 7, moon_loc.y + 13)
          elseif delta == -1 then
            screen.pixel(moon_loc.x + 4, moon_loc.y + 13)
          elseif delta == -2 then
            screen.pixel(moon_loc.x + 4, moon_loc.y + 13)
            screen.pixel(moon_loc.x + 1, moon_loc.y + 13)
          end
          screen.fill()

          if moon_fade_counter > 10 then
            screen.level_a(0, moon_alpha_map[moon_fade_counter - 10])
            screen.rect(moon_loc.x-1, moon_loc.y-1, moon_loc.w+2, moon_loc.w + 5)
            screen.fill()
          end

          screen.update()
        end
        _mod_redraw = redraw
      end
    end
  }
  table.insert(mappable_params_3u, txo_cv_3_oct_delta)
  params:add(txo_cv_3_oct_delta)
  params:hide("txo_cv_3_oct_delta")
  _menu.rebuild_params()

  local crow_env_active = {
    id="crow_env_active",
    name="○ crow env",
    type="binary",
    behavior="toggle",
    default=1,
    action= function(state)
      -- prevent the env params from attempting to set crow public var before they are available
      crow_env_init_3u = false

      -- local function for clock.run
      local function dofunc(z)
        if z == 1 then
        -- if z == 1 and not crow_env_init_3u then
          norns.crow.loadscript("3u-patch-companion/crow/env-public-vars.lua")
          -- loadscript is async, and takes time run
          -- we need to ensure the load is finished before continuing
          -- TODO: find out how to make loadscript synchronous
          clock.sleep(1)
          -- script is loaded, allow env params to set public vars
          crow_env_init_3u = true

          local out = params:get("crow_env_out")
          local input = params:get("crow_env_in")
          local amp = params:get("crow_env_amp")
          local retrig = params:string("crow_env_retrig_behavior")
          local len = params:get("crow_env_time")
          local ratio = params:get("crow_env_ratio")
          local rise = len * ratio
          local fall = len * (1 - ratio)
          local rise_shape = params:string("crow_env_rise_shape")
          local fall_shape = params:string("crow_env_fall_shape")
          local start_stage = ""

          crow.public.envout = out

          if retrig == "from zero" then
            start_stage="to(0, 0),"
          end

          crow.output[out].action = "{ "..start_stage.."to(dyn{amp="..amp.."}, dyn{rise="..rise.."}, '"..rise_shape.."'), to(0, dyn{fall="..fall.."}, '"..fall_shape.."') }"

          crow.output[out].done = function()
            crow.public.envactive = 0
          end

          crow.input[input].mode('change', 1, 0.1, 'rising')

          if retrig == "no retrig" then
            crow.input[input].change = function()
              if crow.public.envactive == 0 then
                crow.public.envactive = 1
                crow.output[crow.public.envout]()
              end
            end
          else
            crow.input[input].change = function()
              crow.public.envactive = 1
              crow.output[crow.public.envout]()
            end
          end

          params:lookup_param("crow_env_active").name = "● crow env"
          params:show("crow_env_time")
          params:show("crow_env_ratio")
          params:show("crow_env_amp")
          params:show("crow_env_retrig_behavior")
          params:show("crow_env_in")
          params:show("crow_env_out")
          _menu.rebuild_params()

          -- there is some kind of ii init that happens when we do the crow stuff above
          -- it clears my values for ii devices like wsyn
          -- need to bang to send the ii messages again
          for _,p in pairs(params.params) do
            if string.match(p.id, "^wsyn") or string.match(p.id, "^txo") then
              p:bang()
            end
          end
        elseif z == 0 then
          params:lookup_param("crow_env_active").name = "○ crow env"
          params:hide("crow_env_time")
          params:hide("crow_env_ratio")
          params:hide("crow_env_amp")
          params:hide("crow_env_retrig_behavior")
          params:hide("crow_env_in")
          params:hide("crow_env_out")
          _menu.rebuild_params()
        end
      end

      clock.run(dofunc, state)
    end
  }
  params:add(crow_env_active)

  local crow_env_time = {
    id="crow_env_time",
    name="crow env time",
    type="control",
    controlspec=controlspec.def{
      min = 0.01,
      max = 4,
      warp = 'exp',
      step = 0.01,
      default = 2,
      quantum = 0.01/(4-0.01),
      wrap = false
    },
    action=function(len)
      if crow_env_init_3u then
        local rise = len * params:get("crow_env_ratio")
        local fall = len * (1 - params:get("crow_env_ratio"))
        local out = params:get("crow_env_out")
        crow.output[out].dyn.rise = rise
        crow.output[out].dyn.fall = fall
      end
    end
  }
  params:add(crow_env_time)
  if params:get("crow_env_active") == 0 then
    params:hide(crow_env_time)
    _menu.rebuild_params()
  end

  local crow_env_ratio = {
    id="crow_env_ratio",
    name="crow env ratio",
    type="control",
    controlspec=controlspec.def{
      min = 0,
      max = 1,
      warp = 'lin',
      step = 0.01,
      default = 0.1,
      quantum = 0.01,
      wrap = false
    },
    action=function(ratio)
      if crow_env_init_3u then
        local rise = params:get("crow_env_time") * ratio
        local fall = params:get("crow_env_time") * (1 - ratio)
        local out = params:get("crow_env_out")
        crow.output[out].dyn.rise = rise
        crow.output[out].dyn.fall = fall
      end
    end
  }
  params:add(crow_env_ratio)
  if params:get("crow_env_active") == 0 then
    params:hide("crow_env_ratio")
    _menu.rebuild_params()
  end

  local crow_env_amp = {
    id="crow_env_amp",
    name="crow env amp",
    type="control",
    controlspec=controlspec.def{
      min = -5,
      max = 10,
      warp = 'lin',
      step = 0.1,
      default = 8,
      quantum = 0.1/15,
      wrap = false
    },
    action=function(amp)
      if crow_env_init_3u then
        local out = params:get("crow_env_out")
        crow.output[out].dyn.amp = amp
      end
    end
  }
  params:add(crow_env_amp)
  if params:get("crow_env_active") == 0 then
    params:hide("crow_env_amp")
    _menu.rebuild_params()
  end

  local crow_env_rise_shape = {
    id="crow_env_rise_shape",
    name="crow env rise shape",
    type="option",
    options={"linear", "exponential", "logarithmic", "sine"},
    action=function()
      if crow_env_init_3u then
        local out = params:get("crow_env_out")
        local amp = params:get("crow_env_amp")
        local len = params:get("crow_env_time")
        local ratio = params:get("crow_env_ratio")
        local rise = len * ratio
        local fall = len * (1 - ratio)
        local rise_shape = params:string("crow_env_rise_shape")
        local fall_shape = params:string("crow_env_fall_shape")
        local retrig = params:string("crow_env_retrig_behavior")
        local start_stage = ""

        if retrig == "from zero" then
          start_stage="to(0, 0),"
        end

        crow.output[out].action = "{ "..start_stage.."to(dyn{amp="..amp.."}, dyn{rise="..rise.."}, '"..rise_shape.."'), to(0, dyn{fall="..fall.."}, '"..fall_shape.."') }"
      end
    end
  }
  params:add(crow_env_rise_shape)
  if params:get("crow_env_active") == 0 then
    params:hide("crow_env_rise_shape")
    _menu.rebuild_params()
  end

  local crow_env_fall_shape = {
    id="crow_env_fall_shape",
    name="crow env fall shape",
    type="option",
    options={"linear", "exponential", "logarithmic", "sine"},
    action=function()
      if crow_env_init_3u then
        local out = params:get("crow_env_out")
        local amp = params:get("crow_env_amp")
        local len = params:get("crow_env_time")
        local ratio = params:get("crow_env_ratio")
        local rise = len * ratio
        local fall = len * (1 - ratio)
        local rise_shape = params:string("crow_env_rise_shape")
        local fall_shape = params:string("crow_env_fall_shape")
        local retrig = params:string("crow_env_retrig_behavior")
        local start_stage = ""

        if retrig == "from zero" then
          start_stage="to(0, 0),"
        end

        crow.output[out].action = "{ "..start_stage.."to(dyn{amp="..amp.."}, dyn{rise="..rise.."}, '"..rise_shape.."'), to(0, dyn{fall="..fall.."}, '"..fall_shape.."') }"
      end
    end
  }
  params:add(crow_env_fall_shape)
  if params:get("crow_env_active") == 0 then
    params:hide("crow_env_fall_shape")
    _menu.rebuild_params()
  end

  local crow_env_retrig_behavior = {
    id="crow_env_retrig_behavior",
    name="crow env retrig",
    type="option",
    options={"from zero", "from current", "no retrig"},
    action=function()
      if crow_env_init_3u then
        local retrig = params:string("crow_env_retrig_behavior")
        local out = params:get("crow_env_out")
        local input = params:get("crow_env_in")
        local amp = params:get("crow_env_amp")
        local len = params:get("crow_env_time")
        local ratio = params:get("crow_env_ratio")
        local rise = len * ratio
        local fall = len * (1 - ratio)

        if retrig == "no retrig" then -- no retrig
          crow.input[input].change = function()
            if crow.public.envactive == 0 then
              crow.public.envactive = 1
              crow.output[crow.public.envout]()
            end
          end
        else
          local rise_shape = params:string("crow_env_rise_shape")
          local fall_shape = params:string("crow_env_fall_shape")
          local start_stage = ""

          -- allow retrig
          crow.input[input].change = function()
            crow.public.envactive = 1
            crow.output[crow.public.envout]()
          end

          if retrig == "from zero" then -- from current
            start_stage="to(0, 0),"
          end

          crow.output[out].action = "{ "..start_stage.."to(dyn{amp="..amp.."}, dyn{rise="..rise.."}, '"..rise_shape.."'), to(0, dyn{fall="..fall.."}, '"..fall_shape.."') }"
        end
      end
    end
  }
  params:add(crow_env_retrig_behavior)
  if params:get("crow_env_active") == 0 then
    params:hide("crow_env_retrig_behavior")
    _menu.rebuild_params()
  end

  local crow_env_in = {
    id="crow_env_in",
    name="crow env trig in",
    type="number",
    min=1,
    max=2,
    default=2,
  }
  params:add(crow_env_in)
  if params:get("crow_env_active") == 0 then
    params:hide("crow_env_in")
    _menu.rebuild_params()
  end

  local crow_env_out = {
    id="crow_env_out",
    name="crow env out",
    type="number",
    min=1,
    max=4,
    default=3,
  }
  params:add(crow_env_out)
  if params:get("crow_env_active") == 0 then
    params:hide("crow_env_out")
    _menu.rebuild_params()
  end

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
  table.insert(mappable_params_3u, crow_clock_output_3)
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
  table.insert(mappable_params_3u, crow_clock_div_x2)
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
  table.insert(mappable_params_3u, wsyn_curve)
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
  table.insert(mappable_params_3u, wsyn_ramp)
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
  table.insert(mappable_params_3u, wsyn_fm_index)
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
  table.insert(mappable_params_3u, wsyn_fm_env)
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
  table.insert(mappable_params_3u, wsyn_fm_ratio)
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
  table.insert(mappable_params_3u, wsyn_lpg_symmetry)
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
  table.insert(mappable_params_3u, wsyn_lpg_time)
  params:add(wsyn_lpg_time)

  function make_txo_voice_show_function(port)
    return function(z)
      local base_id = "txo_voice_"..port
      local show_id = base_id.."_show"
      local base_name = "txo voice "..port

      if z == 1 then
        params:lookup_param(show_id).name = "▼ "..base_name
        params:show(base_id.."_shape")
        params:show(base_id.."_level")
        params:show(base_id.."_attack")
        params:show(base_id.."_decay")
        _menu.rebuild_params()
      else
        params:lookup_param(show_id).name = "▶ "..base_name
        params:hide(base_id.."_shape")
        params:hide(base_id.."_level")
        params:hide(base_id.."_attack")
        params:hide(base_id.."_decay")
        _menu.rebuild_params()
      end
    end
  end

  function make_txo_voice_level_func(port)
    return function(x)
      crow.ii.txo.cv(port, x)
    end
  end

  function make_txo_voice_attack_func(port)
    return function(x)
      crow.ii.txo.env_att(port, x)
    end
  end

  function make_txo_voice_decay_func(port)
    return function(x)
      crow.ii.txo.env_dec(port, x)
    end
  end

  function make_txo_voice_shape_func(port)
    return function(x)
      crow.ii.txo.osc_wave(port, x)
    end
  end

  for i=1,4 do
    local base_id = "txo_voice_"..i
    local show_id = base_id.."_show"
    local base_name = "txo voice "..i

    local show_param = {
      id=show_id,
      name="▶ "..base_name,
      type="binary",
      behavior="toggle",
      default=0,
      action=make_txo_voice_show_function(i)
    }
    if i == 2 or i == 4 then
      show_param.default = 1
    end
    params:add(show_param)

    shape_param = {
      id=base_id.."_shape",
      name=base_name.." shape",
      type="control",
      controlspec=controlspec.def{
        min = 0,
        max = 5000,
        step = 10,
        default = 0,
        units = 'mv',
        quantum = 1/500,
        wrap = false
      },
      action=make_txo_voice_shape_func(i)
    }
    table.insert(mappable_params_3u, shape_param)
    params:add(shape_param)
    if params:get(show_id) == 0 then
      params:hide(base_id.."_shape")
      _menu.rebuild_params()
    end

    local level_param = {
      id=base_id.."_level",
      name=base_name.." level",
      -- type="number",
      -- min=0,
      -- max=4500,
      -- default=0,
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
      -- formatter=function(param) return string.format("%.2f", param:get()) end,
      action=make_txo_voice_level_func(i)
    }
    table.insert(mappable_params_3u, level_param)
    params:add(level_param)
    if params:get(show_id) == 0 then
        params:hide(base_id.."_level")
        _menu.rebuild_params()
    end

    local attack_param = {
      id=base_id.."_attack",
      name=base_name.." attack",
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
      action=make_txo_voice_attack_func(i)
    }
    table.insert(mappable_params_3u, attack_param)
    params:add(attack_param)
    if params:get(show_id) == 0 then
      params:hide(base_id.."_attack")
      _menu.rebuild_params()
    end

    local decay_param = {
      id=base_id.."_decay",
      name=base_name.." decay",
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
      action=make_txo_voice_decay_func(i)
    }
    table.insert(mappable_params_3u, decay_param)
    params:add(decay_param)
    if params:get(show_id) == 0 then
      params:hide(base_id.."_decay")
      _menu.rebuild_params()
    end
  end

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
  table.insert(mappable_params_3u, crow_ins_to_wsyn)
  params:add(crow_ins_to_wsyn)

  -- create key and encoder action params
  key_options_3u = {}
  key_option_to_id_3u = {}
  enc_options_3u = {}
  enc_option_to_id_3u = {}
  trackball_options_3u = {}
  trackball_option_to_id_3u = {}

  table.insert(key_options_3u, "none")
  key_option_to_id_3u["none"] = "empty_param"
  -- table.insert(enc_options, "none")
  -- enc_option_to_id["none"] = "empty_param"
  -- table.insert(trackball_options, "none")
  -- trackball_option_to_id["none"] = "empty_param"

  for i,p in ipairs(mappable_params_3u) do
    if p.type == "binary" then
      table.insert(key_options_3u, p.name)
      key_option_to_id_3u[p.name] = p.id
    elseif p.type == "number" or p.type == "control" then
      table.insert(enc_options_3u, p.name)
      enc_option_to_id_3u[p.name] = p.id
      table.insert(trackball_options_3u, p.name)
      trackball_option_to_id_3u[p.name] = p.id
    end
  end

  local trackball_x_action = {
    id="trackball_x_action",
    name="ball x",
    type="option",
    options=trackball_options_3u,
    default = pfuncs.get_index_of_value(trackball_options_3u, "wsyn fm index"),
  }
  params:add(trackball_x_action)

  local trackball_y_action = {
    id="trackball_y_action",
    name="ball y",
    type="option",
    options=trackball_options_3u,
    default = pfuncs.get_index_of_value(trackball_options_3u, "wsyn lpg time"),
  }
  params:add(trackball_y_action)

  local trackball_scroll_action = {
    id="trackball_scroll_action",
    name="ball scroll",
    type="option",
    options=trackball_options_3u,
    default = pfuncs.get_index_of_value(trackball_options_3u, "wsyn fm ratio"),
  }
  params:add(trackball_scroll_action)

  local trackball_x_invert = {
    id="trackball_x_invert",
    name="invert ball x",
    type="binary",
    behavior="toggle",
    default = 0,
  }
  params:add(trackball_x_invert)

  local trackball_y_invert = {
    id="trackball_y_invert",
    name="invert ball y",
    type="binary",
    behavior="toggle",
    default = 0,
  }
  params:add(trackball_y_invert)

  local trackball_scroll_invert = {
    id="trackball_scroll_invert",
    name="invert ball scroll",
    type="binary",
    behavior="toggle",
    default = 1,
  }
  params:add(trackball_scroll_invert)

  local k2_action = {
    id="k2_action_3u",
    name="k2",
    type="option",
    options=key_options_3u,
    default = pfuncs.get_index_of_value(key_options_3u, "none"),
    action = function(v)
      if v == 1 then -- option 'none'
        params:set("k2_propagate_3u", 1)
        params:hide("k2_propagate_3u")
      else
        params:show("k2_propagate_3u")
      end
      _menu.rebuild_params()
    end
  }
  params:add(k2_action)
  local k2_propagate_3u = {
    id="k2_propagate_3u",
    name="k2 propagate",
    type="binary",
    behavior="toggle",
    default=1,
  }
  params:add(k2_propagate_3u)
  if params:get("k2_action_3u") == 1 then
      params:hide("k2_propagate_3u")
      _menu.rebuild_params()
  end

  local k3_action = {
    id="k3_action_3u",
    name="k3",
    type="option",
    options=key_options_3u,
    default = pfuncs.get_index_of_value(key_options_3u, "none"),
    action = function(v)
      if v == 1 then -- option 'none'
        params:set("k3_propagate_3u", 1)
        params:hide("k3_propagate_3u")
      else
        params:show("k3_propagate_3u")
      end
      _menu.rebuild_params()
    end
  }
  params:add(k3_action)
  local k3_propagate_3u = {
    id="k3_propagate_3u",
    name="k3 propagate",
    type="binary",
    behavior="toggle",
    default=1,
  }
  params:add(k3_propagate_3u)
  if params:get("k3_action_3u") == 1 then
      params:hide("k3_propagate_3u")
      _menu.rebuild_params()
  end

  local e1_action = {
    id="3u_e1_action",
    name="e1",
    type="option",
    options=enc_options_3u,
    default = pfuncs.get_index_of_value(enc_options_3u, "none"),
    action = function(v)
      if v == 1 then -- option 'none'
        params:set("e1_propagate_3u", 1)
        params:hide("e1_propagate_3u")
      else
        params:show("e1_propagate_3u")
      end
      _menu.rebuild_params()
    end
  }
  params:add(e1_action)
  local e1_propagate_3u = {
    id="e1_propagate_3u",
    name="e1 propagate",
    type="binary",
    behavior="toggle",
    default=1,
  }
  params:add(e1_propagate_3u)
  if params:get("3u_e1_action") == 1 then
      params:hide("e1_propagate_3u")
      _menu.rebuild_params()
  end

  local e2_action = {
    id="e2_action_3u",
    name="e2",
    type="option",
    options=enc_options_3u,
    default = pfuncs.get_index_of_value(enc_options_3u, "none"),
    action = function(v)
      if v == 1 then -- option 'none'
        params:set("e2_propagate_3u", 1)
        params:hide("e2_propagate_3u")
      else
        params:show("e2_propagate_3u")
      end
      _menu.rebuild_params()
    end
  }
  params:add(e2_action)
  local e2_propagate_3u = {
    id="e2_propagate_3u",
    name="e2 propagate",
    type="binary",
    behavior="toggle",
    default=1,
  }
  params:add(e2_propagate_3u)
  if params:get("e2_action_3u") == 1 then
      params:hide("e2_propagate_3u")
      _menu.rebuild_params()
  end

  local e3_action = {
    id="e3_action_3u",
    name="e3",
    type="option",
    options=enc_options_3u,
    default = pfuncs.get_index_of_value(enc_options_3u, "none"),
    action = function(v)
      if v == 1 then -- option 'none'
        params:set("e3_propagate_3u", 1)
        params:hide("e3_propagate_3u")
      else
        params:show("e3_propagate_3u")
      end
      _menu.rebuild_params()
    end
  }
  params:add(e3_action)

  local e3_propagate_3u = {
    id="e3_propagate_3u",
    name="e3 propagate",
    type="binary",
    behavior="toggle",
    default=1,
  }
  params:add(e3_propagate_3u)
  if params:get("e3_action_3u") == 1 then
      params:hide("e3_propagate_3u")
      _menu.rebuild_params()
  end

  local draw_changes = {
    id="draw_changes",
    name="draw changes",
    type="binary",
    behavior="toggle",
    default=0
  }
  params:add(draw_changes)

  params:default()
  params:bang()
end)

mod.hook.register("script_post_init", "3u patch companion post init", function()
  capture_redraw()

  key_wrapped = key
  function key(n, z)
    if n == 1 then
      key_wrapped(n,z)
      return
    end

    local id = key_option_to_id_3u[key_options_3u[params:get("k"..n.."_action_3u")]]
    if (id ~= 'empty_param_3u') then
      local behavior = params:lookup_param(id).behavior
      if behavior == "toggle" and z == 1 then
        params:set(id, 1 - params:get(id))
      elseif behavior == "trigger" and z == 1 then
        params:set(id, 1)
      elseif behavior == "momentary" then
        params:set(id, z)
      end
    end

    if params:get("k"..n.."_propagate_3u") == 1 then
      key_wrapped(n, z)
    end
  end

  enc_wrapped = enc
  function enc(n, delta)
    local id = enc_option_to_id_3u[enc_options_3u[params:get("e"..n.."_action_3u")]]
    params:delta(id, delta)

    if params:get("e"..n.."_propagate_3u") == 1 then
      enc_wrapped(n, delta)
    end
  end

  function trackball_input(typ, code, val)
    local param_id
    if code == 0x00 then -- hid_events.codes.REL_X = 0x00
      param_id = trackball_option_to_id_3u[trackball_options_3u[params:get("trackball_x_action")]]
      if (params:get("trackball_x_invert") == 1) then
        val = -val
      end
    elseif code == 0x01 then -- hid_events.codes.REL_Y = 0x01
      param_id = trackball_option_to_id_3u[trackball_options_3u[params:get("trackball_y_action")]]
      if (params:get("trackball_y_invert") == 1) then
        val = -val
      end
    elseif code == 0x08 then -- hid_events.codes.REL_WHEEL = 0x08
      param_id = trackball_option_to_id_3u[trackball_options_3u[params:get("trackball_scroll_action")]]
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

function capture_redraw()
  if redraw_capture_metro then
    print("redraw capture metro already exists")
  end

  redraw_capture_metro = metro.init(function()
    if _menu.mode == true then
      return
    elseif _menu.mode == false then
      _script_redraw = redraw
      metro.free(redraw_capture_metro.id)
      redraw_capture_metro = nil
    else
      print("_menu.mode behavior has changed, mod unable to wrap script's redraw function")
    end
  end, 1/10)
  redraw_capture_metro:start()
end

function restore_redraw(redraw_func)
  if redraw_restore_metro then
    print("redraw restore metro already exists")
    return
  elseif redraw_func == nil then
    print("redraw restore function cannot be nil")
    return
  end

  redraw_restore_metro = metro.init(function()
    if _menu.mode == true then
      return
    elseif _menu.mode == false then
      redraw = redraw_func
      metro.free(redraw_restore_metro.id)
      redraw_restore_metro = nil
    else
      print("_menu.mode behavior has changed, mod unable to restore script's redraw function")
    end
  end, 1/10)
  redraw_restore_metro:start()
end

