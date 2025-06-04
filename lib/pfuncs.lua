-- functions called by params
local pfuncs = {}

pfuncs.get_index_of_value = function(t, val)
  for k,v in pairs(t) do
    if v == val then
      return k
    end
  end
end

pfuncs.crow_ins_to_wsyn_start = function ()
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

pfuncs.crow_ins_to_wsyn_stop = function ()
    for i = 1, 2 do
        crow.input[i] { mode = 'none' }
    end
end

pfuncs.clear_ii_voices = function ()
    crow.ii.wsyn.play_voice(1, 1, 0)
    crow.ii.wsyn.play_voice(2, 1, 0)
    crow.ii.wsyn.play_voice(3, 1, 0)
    crow.ii.wsyn.play_voice(4, 1, 0)
end

return pfuncs
