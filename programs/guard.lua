local sensor = peripheral.wrap("right")

local function scan(radius)
    radius = radius or 16
    local space = { radius = radius }
    for x = -radius, radius do
        space[x] = {}
        for y = -radius, radius do
            space[x][y] = {}
        end
    end
    for _, block in pairs(sensor.sonicScan()) do
        if block.x >= -radius and block.x < radius and
           block.y >= -radius and block.y < radius and
           block.z >= -radius and block.z < radius 
        then
            space[block.x][block.y][block.z] = block.type == "AIR"
        end
    end
    return space
end

local function search(space, orientation, target)
    local r = space.radius

    local function successors(state)    
        local alternatives = {
            { x =  1, y =  0, z =  0, d = "+x" },
            { x = -1, y =  0, z =  0, d = "-x" },
            { x =  0, y =  1, z =  0, d = "+y" },
            { x =  0, y = -1, z =  0, d = "-y" },
            { x =  0, y =  0, z =  1, d = "+z" },
            { x =  0, y =  0, z = -1, d = "-z" },
        }
        local succs = {}
        for _, d in ipairs(alternatives) do
            if state.x + d.x >= -r and state.x + d.x < -r and
               state.y + d.y >= -r and state.y + d.y < -r and
               state.z + d.z >= -r and state.z + d.z < -r and
               space[state.x + d.x][state.y + d.y][state.z + d.z] 
           then
                local actions = {}
                local newState = { x = state.x + d.x, y = state.y + d.y,
                    z = state.z + d.z, o = state.o }
                    
                if d.d == "+y" then
                    table.insert(actions, "up")                    
                elseif d.d == "-y" then
                    table.insert(actions, "down")
                elseif d.d == state.o then
                    table.insert(actions, "forward")
                elseif d.d:sub(2,2) == state.o:sub(2,2) then
                    table.insert(actions, "back")
                else 
                    if d.d:sub(1,1) == state.o:sub(1,1) then
                        if d.d:sub(1,1) == "x" then
                            table.insert(actions, "turnLeft")
                        else
                            table.insert(actions, "turnRight")
                        end
                    else
                        if d.d:sub(1,1) == "z" then
                            table.insert(actions, "turnLeft")
                        else
                            table.insert(actions, "turnRight")
                        end
                    end
                    table.insert(actions, "forward")                    
                end
                
                table.insert(succs, { 
                    state = newState,    
                    actions = actions  
                })
                
                newState.o = d.d
            end            
        end
        
        return succs
    end

    local function hash(state)
        --[[
        local bits = math.ceil(math.log(r * 2 + 1) / math.log(2))
        
        local x = bit.blshift(state.x + r + 1, bits * 2)
        local y = bit.blshift(state.y + r + 1, bits)
        local z = state.z + r + 1
        
        return bit.bor(x, bit.bor(y, z))
        ]]
        
        return state.x .. "," .. state.y .. "," .. state.z
    end
    
    if target.x > r or target.x < -r or 
       target.y > r or target.y < -r or 
       target.z > r or target.z < -r 
    then
        return nil
    end

    local initial = { 
        state = { x = 0, y = 0, z = 0, o = orientation },
        actions = {},
        cost = 0,
    }
    local queue = { initial }
    local closed = { [hash(initial.state)] = true }
    
    repeat
        local node = table.remove(queue, 1)
        if node.state.x == target.x and
           node.state.y == target.y and
           node.state.z == target.z 
        then
            local path = {}
            repeat
                for index, action in ipairs(node.actions) do
                    table.insert(path, index, action)
                end
                node = node.prev                
            until not node
            
            return path
        end
        
        closed[hash(node.state)] = true
        
        for _, s in ipairs(successors(node.state)) do
            if not closed[hash(s.state)] then
                s.prev = node
                s.cost = node.cost + #s.actions
                local inserted = false
                for i, n in ipairs(queue) do
                    if n.cost > s.cost then
                        table.insert(queue, i, s)
                        inserted = true
                        break
                    end
                end
                if not inserted then
                    table.insert(queue, s)
                end
            end
        end
    until #queue == 0
    
    return nil    
end

local space = scan(1)
local path = search(space, "+x", { x = 1, y = 0, z = 0 })
if path then
    for _, a in ipairs(path) do
        turtle[a]()
    end
else
    print("No path!")
end
