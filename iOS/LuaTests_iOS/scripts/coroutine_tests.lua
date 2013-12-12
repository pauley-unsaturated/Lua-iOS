local M = {}

function doState(state)
  returnVal, nextState = state()
  coroutine.yield(returnVal)
  if (nextState == 0) then
    return nextState;
  end
  return doState(nextState)
end

local function stateOne()
  return 1, stateTwo
end

local function stateTwo()
  return 2, stateThree
end

local function stateThree()
  return 3, 0
end

local function startState()
  return stateOne
end

function M.new()
  return coroutine.create( 
    function ()
      doState(startState())
    end
  )
end

return M