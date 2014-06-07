-- Give the turtle fuel to work with
if turtle.getFuelLevel() < 50 then
  print("Please give me fuel!")
  local oldFuelLevel = turtle.getFuelLevel()
  while oldFuelLevel <= turtle.getFuelLevel() do
    os.sleep(1)
    turtle.refuel()
  end
  print('Mmmh, thank you master!')
end
 
-- Move under the tree
turtle.dig()
turtle.forward()
 
-- Test if we have a 3 by 3 tree
local isStarTree = false
local is33Tree = false
turtle.dig()
turtle.forward()
if turtle.compare() then
  print('This is a star tree')
  isStarTree = true
  turtle.dig()
  turtle.forward()
  turtle.turnLeft()
  if turtle.compare() then
    print('This is a 3x3 tree')
    is33Tree = true
  end
  turtle.turnRight()
end
turtle.back()
 
local layer = 0

function ensureFuel()
  while (turtle.getItemCount(1) > 0) and (turtle.getFuelLevel() < 100 + layer) do
    turtle.refuel(1)
  end
end
 
local continue = true
while continue do
  if isStarTree then
    for dir = 1,4 do
      turtle.dig()
      if is33Tree then
        turtle.forward()
        turtle.turnLeft()
        turtle.dig()
        turtle.turnRight()
        turtle.back()
      end
      turtle.turnLeft()
    end
  end
 
  continue = turtle.compareUp()
  if continue then
    turtle.digUp()
    turtle.up()
    layer = layer + 1
  end

  ensureFuel()
end
 
print("I am done... returning...")
 
for layerIndex = 1,layer do
  turtle.down()
end
 
print("I am done master!")
