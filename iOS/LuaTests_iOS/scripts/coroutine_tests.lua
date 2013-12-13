local M = {}

function doState(state)
  returnVal, nextState = state()
  if (nextState == 0) then
    return returnVal;
  else
    coroutine.yield(returnVal)
    return doState(nextState)
  end
end

function stateOne()
  return 1, stateTwo
end

function stateTwo()
  return 2, stateThree
end

function stateThree()
  return 3, 0
end

function startState()
  return stateOne
end

function M.new()
  return coroutine.create( 
    function ()
      return doState(startState())
    end
  )
end

return M