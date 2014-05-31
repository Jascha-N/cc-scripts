local SCAN_RADIUS    = 5
local HASH_BITS      = math.ceil(math.log(SCAN_RADIUS * 2 + 1) / math.log(2))
local YIELD_INTERVAL = 5

local DIR_POS_X, DIR_POS_Z, DIR_NEG_X, DIR_NEG_Z, DIR_COUNT = 0, 1, 2, 3, 4
local SENSOR = peripheral.wrap("right")

local function scan()
    radius = radius or 16
    local space = { radius = radius }
    for x = -radius, radius do
        space[x] = {}
        for y = -radius, radius do
            space[x][y] = {}
        end
    end
    for _, block in pairs(SENSOR.sonicScan()) do
        if block.x >= -radius and block.x <= radius and
           block.y >= -radius and block.y <= radius and
           block.z >= -radius and block.z <= radius 
        then
            space[block.x][block.y][block.z] = block.type == "AIR"
        end
    end
    space[0][0][0] = true
    return space
end

local function search(space, startDir, target, heuristic)
    local r = space.radius
    local h = heuristic or (function(s, t) return 0 end)

    local function successors(state)    
        local alternatives = {
            { x =  1, y =  0, z =  0, dir = DIR_POS_X },
            { x = -1, y =  0, z =  0, dir = DIR_NEG_X },
            { x =  0, y =  1, z =  0 },
            { x =  0, y = -1, z =  0 },
            { x =  0, y =  0, z =  1, dir = DIR_POS_Z },
            { x =  0, y =  0, z = -1, dir = DIR_NEG_Z },
        }
        local succs = {}
        for _, delta in ipairs(alternatives) do
            if state.x + delta.x >= -r and state.x + delta.x <= r and
               state.y + delta.y >= -r and state.y + delta.y <= r and
               state.z + delta.z >= -r and state.z + delta.z <= r and
               space[state.x + delta.x][state.y + delta.y][state.z + delta.z] 
           then
                local actions = {}
                local newState = { x = state.x + delta.x, y = state.y + delta.y,
                    z = state.z + delta.z, dir = state.dir }
                    
                if delta.y > 0 then
                    table.insert(actions, "up")                    
                elseif delta.y < 0 then
                    table.insert(actions, "down")
                elseif delta.dir == state.dir then
                    table.insert(actions, "forward")
                elseif math.abs(delta.dir - state.dir) == 2 then
                    table.insert(actions, "back")
                else 
                    if delta.dir == (state.dir + 1) % DIR_COUNT then
                        table.insert(actions, "turnRight")
                    else
                        table.insert(actions, "turnLeft")
                    end
                    table.insert(actions, "forward")
                    newState.dir = delta.dir
                end
                
                table.insert(succs, { 
                    state = newState,    
                    actions = actions  
                })
            end            
        end
        
        return succs
    end

    local function hash(state)        
        local x = bit.blshift(state.x + r + 1, HASH_BITS * 2)
        local y = bit.blshift(state.y + r + 1, HASH_BITS)
        local z = state.z + r + 1
        
        return bit.bor(x, bit.bor(y, z))
    end
    
    local function extractPath(node)
        local path = {}
        repeat
            for index, action in ipairs(node.actions) do
                table.insert(path, index, action)
            end
            node = node.prev                
        until not node
        
        return path
    end
    
    assert(target.x > r or target.x < -r or 
           target.y > r or target.y < -r or 
           target.z > r or target.z < -r,
           "target out of range")

    local initial = { 
        state = { x = 0, y = 0, z = 0, dir = startDir },
        actions = {},
        cost = 0,
    }
    initial.estimate = h(initial.state, target)
    local best = initial
    
    local queue = { initial }
    local closed = { [hash(initial.state)] = true }
    local lastTime = os.clock()
    repeat    
        local node = table.remove(queue, 1)
        if node.state.x == target.x and
           node.state.y == target.y and
           node.state.z == target.z 
        then
            local path = extractPath(node)
            path.partial = false
            return path
        elseif node.estimate < best.estimate or
               node.estimate == best.estimate and
               node.cost < best.cost
        then
            best = node
        end
        
        closed[hash(node.state)] = true
        
        for _, s in ipairs(successors(node.state)) do
            if not closed[hash(s.state)] then
                s.prev = node
                s.cost = node.cost + #s.actions
                s.estimate = h(s.state, target)
                local inserted = false
                for i, n in ipairs(queue) do
                    if n.cost + n.estimate > s.cost + s.estimate then
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
        
        local t = os.clock()
        if t >= lastTime + YIELD_INTERVAL then
            sleep(0)
            lastTime = t
        end        
    until #queue == 0
    
    local path = extractPath(node)
    path.partial = true
    return path   
end

local space = scan(SCAN_RADIUS)

local function manhattan(state, target)
    return math.abs(state.x - target.x) +
           math.abs(state.y - target.y) +
           math.abs(state.z - target.z)
end
     
local path = search(space, DIR_POS_X, { x = -5, y = 0, z = 0 }, manhattan)
if path then
    for _, a in ipairs(path) do
        print(a)
        turtle[a]()
    end
else
    print("No path!")
end
