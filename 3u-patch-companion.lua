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

-- these clock params just expose relevant clock params next to the other params
params:add{
  id="clock_bpm",
  name="clock bpm",
  type="number",
  min=1,
  max=300,
  default=params:get("clock_tempo"),
  action=function(x) params:set("clock_tempo", x) end
}
params:add{
  id="crow_clock_output_3",
  name="crow clock output 3",
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
params:add{
  id="wsyn curve",
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
params:add{
  id="wsyn ramp",
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
params:add{
  id="wsyn fm index",
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
params:add{
  id="wsyn fm env",
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
params:add{
  id="wsyn fm ratio",
  type="number",
  min=1,
  max=24,
  default=4,
  action=function(x) crow.ii.wsyn.fm_ratio(x) end
}
params:add{
  id="wsyn lpg symmetry",
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
params:add{
  id="wsyn lpg time",
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

params:add{
  id="txo waveshape - voice 3",
  type="number",
  min=0,
  max=4500,
  default=0,
  action=function(x) crow.ii.txo.osc_wave(3, x) end
}
params:add{
  id="txo level - voice 3",
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
params:add{
  id="txo attack - voice 3",
  type="number",
  min=0,
  max=5000,
  default=40,
  action=function(x) crow.ii.txo.env_att(3, x) end
}
params:add{
  id="txo decay - voice 3",
  type="number",
  min=0,
  max=10000,
  default=2000,
  action=function(x) crow.ii.txo.env_dec(3, x) end
}
params:add{
  id="txo waveshape - voice 4",
  type="number",
  min=0,
  max=4500,
  default=0,
  action=function(x) crow.ii.txo.osc_wave(4, x) end
}
params:add{
  id="txo attack - voice 4",
  type="number",
  min=0,
  max=5000,
  default=40,
  action=function(x) crow.ii.txo.env_att(4, x) end
}
params:add{
  id="txo decay - voice 4",
  type="number",
  min=0,
  max=10000,
  default=1000,
  action=function(x) crow.ii.txo.env_dec(4, x) end
}
params:add{
  id="crow_ins_to_wsyn",
  name="crow ins to wsyn",
  type="binary",
  behavior="toggle",
  default=0,
  action=function(x)
    if x == 1 then
      crow_ins_to_wsyn_start()
    else
      crow_ins_to_wsyn_stop()
    end
  end
}
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

function crow_ins_to_wsyn_start()
    --[[
  pos: should be 0-1
  points: an array of tables. the tables should have 2 indexes, 'pos' and 'val'.
      - pos: the actual knob position to map to val
      - val: the position that would be output if the knob were set to the actual position specified by pos
      knobPos will be smoothly mapped to the the output between the points
      the array of tables must be sorted by the table's pos and val, and sorting by either of the tables' indices should result in the same sort
      the last table in the array should be {pos=1,val=1}
      ex. one point with pos .5 and value .2 would cause the first 50% of the knob to map to 0-.2, and the second half to map to .2-1
  --]]
  function varisponse(vin, points)
      vin = math.max(points[1].vin, math.min(vin, points[#points].vin))

      for i = 2, #points do
          if points[i].vin >= vin then -- hit
              local vinBottom = points[i - 1].vin
              local voutBottom = points[i - 1].vout
              local vinRange = points[i].vin - vinBottom
              local voutRange = points[i].vout - voutBottom
              local segmentPercentage = (vin - vinBottom) / vinRange
              local segmentVal = segmentPercentage * voutRange

              return voutBottom + segmentVal
          end
      end
  end

  -- tune these response curves to taste
  -- vin is the value at the input, vout is the output value that voltage will be equal to
  -- values between the defined points are linearly interpolated
  -- this allows for ex. making the first half of the knob much more sensitive than the last half, for ex. fine-tuning a short envelope
  ins = {
      {
          callback = function(v)
              -- ii.wsyn.fm_env(varisponse(v, {
              --     { vin = 0,   vout = 0 },
              --     { vin = 0.3, vout = 0 },
              --     { vin = 3.5, vout = 0.1 },
              --     { vin = 6,   vout = 1 },
              --     { vin = 10,  vout = 3 },
              -- }))
              crow.ii.wsyn.fm_index(varisponse(v, {
                  { vin = 0,   vout = 0 },
                  { vin = 0.3, vout = 0 }, -- wiggle room for left side of joystick
                  { vin = 2.5, vout = 0.3 },
                  { vin = 6,   vout = 1 },
                  { vin = 10,  vout = 3 },
              }))
          end,
      },
      {
          callback = function(v)
              crow.ii.wsyn.lpg_time(varisponse(v, {
                  { vin = 0,   vout = 4 },
                  { vin = 0.1, vout = 3 },
                  { vin = 0.5, vout = 1 },
                  { vin = 3,   vout = -1 },
                  { vin = 8,   vout = -3 },
                  { vin = 10,  vout = -4 }
              }))
          end,
      }
  }

  -- crow.input[i] { mode = 'stream'
  -- , time = 0.01
  -- , stream = function(v) ins[i].callback(v) end }
  crow.input[i].stream = function(v) ins[i].callback(v) end
  crow.input[i].mode("stream", 0.01)
end

function crow_ins_to_wsyn_stop()
    for i = 1, 2 do
        crow.input[i] { mode = 'none' }
    end
end
