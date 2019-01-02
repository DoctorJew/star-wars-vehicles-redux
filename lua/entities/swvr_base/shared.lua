--- Star Wars Vehicles Flight Base
-- @module Vehicle
-- @alias ENT
-- @author Doctor Jew

ENT.Type = "anim"

--- Nice display name of the entity
ENT.PrintName = "SWVR Base"

--- Author of the `Entity`
ENT.Author = "Doctor Jew"

ENT.Information = ""

--- `Entity` category, used to assign to a faction
ENT.Category = "Other"

--- Vehicle class (fighter, bomber, etc.)
ENT.Class = "Other"
ENT.IsSWVRVehicle = true

ENT.Spawnable = false
ENT.AdminSpawnable = false

ENT.AutomaticFrameAdvance = true
ENT.Rendergroup = RENDERGROUP_BOTH
ENT.Editable =  true

-- Customizable Settings

--- Maximum health of the vehicle
ENT.MaxHealth = 1000

--- Maximum shields of the vehicle, if any
ENT.MaxShield = 0

ENT.Mass = 2000
ENT.Inertia = Vector(250000, 250000, 250000)

ENT.MaxVelocity = 2500
ENT.MinVelocity = 1

ENT.MaxPower = 500

ENT.MaxThrust = 1200
ENT.BoostThrust = 2000

--- How fast can the vehicle pitch/yaw/roll?
ENT.Handling = Vector(300, 300, 300)
ENT.Landing = {}

ENT.Controls = {
  Wings = Vector(),
  Elevator = Vector(),
  Rudder = Vector(),
  Thrust = Vector()
}

ENT.Throttle = Vector()

ENT.Acceleration = Vector()

ENT.Engines = nil
ENT.Parts = nil
ENT.Seats = nil

-- Base Setup and Networking

local AccessorBool = swvr.util.AccessorBool

--- Setup functions
-- @section setup

--- Setups the internal DTVars which creates getters/setters.
-- @shared
-- @internal
function ENT:SetupDataTables()
  self:NetworkVar("Bool", 0, "Active")
  self:NetworkVar("Bool", 1, "Destroyed")
  self:NetworkVar("Bool", 2, "EngineActive")

  self:NetworkVar("Int", 0, "Allegiance", { KeyName = "allegiance", Edit = { type = "Int", order = 1, min = 0, max = 2, category = "Details" } })
  self:NetworkVar("Int", 1, "SeatCount")
  self:NetworkVar("Int", 2, "WeaponCount")

  self:NetworkVar("Float", 0, "HP", { KeyName = "health", Edit = { type = "Float", order = 1, min = 0, max = self.MaxHealth, category = "Condition" } })
  self:NetworkVar("Float", 1, "MaxHP")
  self:NetworkVar("Float", 2, "Shield", { KeyName = "shield", Edit = { type = "Float", order = 2, min = 0, max = self.MaxShield or 0, category = "Condition" } })
  self:NetworkVar("Float", 3, "MaxShield")

  self:NetworkVar("Float", 4, "Thrust")
  self:NetworkVar("Float", 5, "TargetThrust")
  self:NetworkVar("Float", 6, "MaxThrust")
  self:NetworkVar("Float", 7, "BoostThrust")
  self:NetworkVar("Float", 8, "MaxVerticalThrust")

  self:NetworkVar("Float", 9, "NextPrimaryFire")
  self:NetworkVar("Float", 10, "NextSecondaryFire")
  self:NetworkVar("Float", 11, "NextAlternateFire")

  self:NetworkVar("Float", 12, "MaxVelocity")
  self:NetworkVar("Float", 13, "MaxPower")

  self:NetworkVar("Float", 14, "PrimaryOverheat")
  self:NetworkVar("Float", 15, "SecondaryOverheat")

  self:NetworkVar("String", 0, "Transponder")

  -- Generate nice helper functions
  AccessorBool(self, "Destroyed", "Is")
  AccessorBool(self, "Active", "Is")
  AccessorBool(self, "EngineActive", "")

  if SERVER then
    self:NetworkVarNotify("HP", function(ent, name, old, new)
      ent:SetHealth(new)
    end)

    self:NetworkVarNotify("MaxHP", function(ent, name, old, new)
      ent:SetMaxHealth(new)
    end)

    self:SetActive(false)
    self:SetDestroyed(false)
    self:SetEngineActive(false)

    self:SetMaxVelocity(self.MaxVelocity)
    self:SetHP(self.MaxHealth)
    self:SetShield(self.MaxShield or 0)
    self:SetMaxShield(self.MaxShield or 0)
    self:SetMaxHP(self.MaxHealth)

    self:SetThrust(0)
    self:SetMaxThrust(self.MaxThrust)
    self:SetBoostThrust(self.BoostThrust)
    self:SetMaxVerticalThrust(isnumber(self.MaxVerticalThrust) and self.MaxVerticalThrust or self:GetMaxThrust() * 0.15)

    self:SetMaxPower(self.MaxPower)

    self:SetNextPrimaryFire(CurTime())
    self:SetNextSecondaryFire(CurTime())
    self:SetNextAlternateFire(CurTime())

    self:SetAllegiance(1)
    self:SetSeatCount(0)
  end

  self:SetupCustomDataTables()
end

function ENT:SetupCustomDataTables()

end

--- Setup default vehicle events. This is shared but will product different results on client/server.
-- @shared
-- @tparam table options The events to explicitly disable
function ENT:SetupDefaults(options)
  options = options or {}

  if SERVER then
    if options.OnEnter ~= false then
      self:AddEvent("OnEnter", function(ent, ply, pilot)
        if not pilot then return end
        ent:EmitSound("vehicles/atv_ammo_close.wav")
      end)
    end

    if options.OnExit ~= false then
      self:AddEvent("OnExit", function(ent, ply, pilot)
        if not pilot then return end
        ent:EmitSound("vehicles/atv_ammo_open.wav")
      end)
    end
  end
end

-- Vehicle Physics

function ENT:GetStability()
  return self:WaterLevel() > 2 and 0 or (self:IsDestroyed() and 0.1 or (self:EngineActive() and 0.7 or 0))
end

--- Seat Functions
-- @section seats

--- Add a seat to the vehicle. The first seat is always the pilot.
-- @server
-- @string name The name of the seat for easy reference
-- @vector pos The position of the seat in local coordinated
-- @angle ang The angles of the seat in local angles
-- @treturn entity The seat `Entity` itself for convenience
function ENT:AddSeat(name, pos, ang)
  if CLIENT then return end

  assert(not self.Initialized, "[SWVR] Seats cannot be added after the vehicle is initialized! (This can cause weird bugs)")

  local seat = ents.Create("prop_vehicle_prisoner_pod")

  if not IsValid(seat) then SafeRemoveEntity(self) error("[SWVR] Failed to create a seat for a vehicle! Removing vehicle safely.") end

  seat:SetMoveType(MOVETYPE_NONE)
  seat:SetModel("models/nova/airboat_seat.mdl")
  seat:SetKeyValue("vehiclescript", "scripts/vehicles/prisoner_pod.txt")
  seat:SetKeyValue("limitview", 0)
  seat:SetPos(pos and self:LocalToWorld(pos) or self:GetPos())
  seat:SetAngles(ang and self:LocalToWorldAngles(ang) or self:GetAngles())
  seat:SetOwner(self)
  seat:Spawn()
  seat:Activate()
  seat:SetParent(self)
  seat:SetNotSolid(true)
  seat:DrawShadow(false)
  seat:SetColor(Color(255, 255, 255, 0))
  seat:SetRenderMode(RENDERMODE_TRANSALPHA)
  seat.DoNotDuplicate = true

  local phys = seat:GetPhysicsObject()

  if IsValid(phys) then
    phys:EnableDrag(false)
    phys:EnableMotion(false)
    phys:SetMass(1)
  end

  self:DeleteOnRemove(seat)

  seat:SetNWBool("SWVRSeat", true)
  seat:SetNWInt("SWVR.SeatIndex", self:GetSeatCount() + 1)
  seat:SetNWString("SWVR.SeatName", string.upper(name))

  -- CPPI support
  if seat.CPPISetOwner and self.CPPIGetOwner then
    seat:CPPISetOwner(self:CPPIGetOwner())
  end

  self:SetSeatCount(self:GetSeatCount() + 1)

  return seat
end

--- Retrieve an actual seat entity.
-- @shared
-- @param index The index of the seat. Can be a number or string.
-- @treturn entity The found `Entity` or `NULL`
function ENT:GetSeat(index)
  self.Seats = self.Seats or {}

  -- Have we cached the entity for the server/client?
  local seat = self.Seats[index]
  if IsValid(seat) and ((isstring(index) and seat:GetNWString("SWVR.SeatName") == index) or (isnumber(index) and seat:GetNWInt("SWVR.SeatIndex") == index)) then
    return seat
  end

  -- Loop over children instead of Seats table because the table isn't networked but children are
  for _, child in ipairs(self:GetChildren()) do
    if not (child:IsVehicle() and child:GetClass():lower() == "prop_vehicle_prisoner_pod") then continue end

    if isstring(index) and child:GetNWString("SWVR.SeatName", "") ~= string.upper(index) then continue end
    if isnumber(index) and child:GetNWInt("SWVR.SeatIndex", 0) ~= index then continue end

    self.Seats[index] = child

    return child
  end

  return NULL
end

--- Get all the seats of a vehicle.
-- @shared
-- @treturn table Table of `Entity` classes of seats
function ENT:GetSeats()
  self.Seats = self.Seats or {}

  -- Have we cached the seats?
  if #self.Seats == self:GetSeatCount() then return self.Seats end

  -- We must be missing some seats then

  local seats = {}
  for _, child in ipairs(self:GetChildren()) do
    if not (child:IsVehicle() and child:GetClass():lower() == "prop_vehicle_prisoner_pod") then continue end
    if child:GetNWInt("SWVR.SeatIndex", 0) < 1 then continue end

    seats[child:GetNWInt("SWVR.SeatIndex", 0)] = child
  end

  self.Seats = seats

  return self.Seats or {}
end

--- Weapon Functions
-- @section weapons

function ENT:AddWeaponGroup(name)
  if CLIENT then return end

  local ent = ents.Create("prop_physics")
  ent:SetModel("models/props_junk/PopCan01a.mdl")
  ent:SetPos(self:GetPos())
  ent:SetAngles(self:GetAngles())
  ent:SetParent(self)
  ent:Spawn()
  ent:Activate()
  ent:SetRenderMode(RENDERMODE_TRANSALPHA)
  ent:SetColor(Color(255, 255, 255, 0))
  ent:SetSolid(SOLID_NONE)
  ent:AddFlags(FL_DONTTOUCH)

  local phys = ent:GetPhysicsObject()
  phys:EnableCollisions(false)
  phys:EnableMotion(false)

end

--- Add a weapon to the vehicle.
-- @server
-- @string name The name of the weapon
-- @vector[opt] pos The position of the weapon
-- @func[opt] callback Callback used to update entity positioning
-- @treturn entity The new weapon `Entity` for convenience
function ENT:AddWeapon(name, pos, callback)
  if CLIENT then return end

  local ent = ents.Create("prop_physics")
  ent:SetModel("models/props_junk/PopCan01a.mdl")
  ent:SetPos(pos and self:LocalToWorld(pos) or self:GetPos())
  ent:SetAngles(self:GetAngles())
  ent:SetParent(self)
  ent:Spawn()
  ent:Activate()
  ent:SetRenderMode(RENDERMODE_TRANSALPHA)
  ent:SetColor(Color(255, 255, 255, 0))
  ent:SetSolid(SOLID_NONE)
  ent:AddFlags(FL_DONTTOUCH)

  local phys = ent:GetPhysicsObject()
  phys:EnableCollisions(false)
  phys:EnableMotion(false)

  ent:SetNWString("SWVR.WeaponName", name)

  self:SetWeaponCount(self:GetWeaponCount() + 1)

  return ent
end

--- Retrieve one of the vehicle's weapons
-- @shared
-- @string name The name of the weapon to retrieve
-- @treturn entity The found `Entity` or `NULL`
function ENT:GetWeapon(name)
  self.Weapons = self.Weapons or {}

  if not isstring(name) then return NULL end

  -- Have we cached the entity for the server/client?
  local weapon = self.Weapons[name]
  if IsValid(weapon) and weapon:GetNWString("SWVR.WeaponName") == name then
    return weapon
  end

  -- Loop over children instead of Seats table because the table isn't networked but children are
  for _, child in ipairs(self:GetChildren()) do
    if child:GetClass():lower() ~= "prop_physics" then continue end

    if string.upper(child:GetNWString("SWVR.WeaponName", "")) ~= string.upper(name) then continue end

    self.Weapons[name] = child

    return child
  end

  return NULL
end

--- Get all the vehicle's weapons
-- @shared
-- @treturn table Table of `Entity` classes
function ENT:GetWeapons()
  self.Weapons = self.Weapons or {}

  -- Have we cached the weapons?
  if #self.Weapons == self:GetWeaponCount() then return self.Weapons end

  -- We must be missing some weapons then

  local weapons = {}
  for _, child in ipairs(self:GetChildren()) do
    if child:GetClass():lower() ~= "prop_physics" then continue end
    if child:GetNWString("SWVR.WeaponName", "NULL_") == "NULL_" then continue end

    weapons[child:GetNWString("SWVR.WeaponName", "")] = child
  end

  self.Weapons = weapons

  return self.Weapons or {}
end

--- Fire one of the vehicle's weapons
-- @server
-- @string name The name of the weapon to fire
-- @tab[opt] options The options for the weapon
function ENT:FireWeapon(name, options)
  if CLIENT then return end

  options = options or {}

  local wtype = options.Type or "cannon"
  local t = wtype:sub(1,1):upper() .. wtype:sub(2):lower()

  if self["Fire" .. t] then self["Fire" .. t](self, name, options) end
end

function ENT:FireCannon(name, options)
  local weapon = self:GetWeapon(name)

  if not IsValid(weapon) then return end

  local bullet = {}
  bullet.Num = 1
  bullet.Src = weapon:GetPos() or self:GetPos()
  bullet.Dir = weapon:GetAngles():Forward() or self:GetAngles():Forward()
  bullet.Spread = options.Spread or Vector(0.01, 0.01, 0)
  bullet.Tracer	= 1
  bullet.TracerName	= options.Tracer or "swvr_tracer_red"
  bullet.Force = 100
  bullet.HullSize = 25
  bullet.Damage	= options.Damage or 40
  bullet.Attacker = options.Attacker or self:GetPilot()
  bullet.AmmoType = "Pistol"
  bullet.Callback = function(att, tr, dmginfo)
    dmginfo:SetDamageType(DMG_AIRBOAT)
  end

  self:FireBullets(bullet)
end

function ENT:FireMissile(name, options)
  options = options or {}

  local weapon = self:GetWeapon(name)

  if not IsValid(weapon) then return end

  local tr = util.TraceHull({
    start = self:GetPos(),
    endpos = self:GetPos() + self:GetForward() * 10000,
    mins = Vector(-32, -32, -32),
    maxs = Vector(32, 32, 32),
    filter = { self }
  })

  local pos = self:LocalToWorld(options.Pos) or weapon:GetPos()

  local ent = ents.Create("lunasflightschool_missile")
  ent:SetPos()
  ent:SetAngles((tr.HitPos - pos):Angle())
  ent:Spawn()
  ent:Activate()
  ent:SetAttacker(options.Attacker or self:GetPilot())
  ent:SetInflictor(self)
  ent:SetStartVelocity(self:GetVelocity():Length())
  ent:SetCleanMissile(true)

  if tr.Hit and IsValid(tr.Entity) and tr.Entity:GetClass():lower() ~= "lunasflightschool_missile" then
    ent:SetLockOn(tr.Entity)
    ent:SetStartVelocity(0)
  end

  constraint.NoCollide(ent, self, 0, 0)

  return ent
end

function ENT:FindTarget()
  local targets = ents.FindInCone(self:GetPos(), self:GetForward(), 100000, math.cos(0.1))

  for _, ent in pairs(targets) do
    -- TODO Check for ships that can't be locked on to (cloak/jammer/etc.)
    if (IsValid(ent) and ent.IsSWVRVehicle and ent ~= self and not IsValid(ent:GetParent()) and ent:GetAllegiance() ~= self:GetAllegiance()) then
      local origin = ent:GetPos() - self:GetPos()
      origin:Normalize()
      origin = self:GetPos() + origin * 100

      local tr = util.TraceLine({
        start = origin,
        endpos = ent:GetPos()
      })

      if (not tr.HitWorld) then
        return ent
      end
    end
  end

  return NULL
end

--- Convenience Functions
-- @section helpers

--- Get the pilot of the vehicle.
-- @shared
-- @treturn player The pilot of the ship
-- @see ENT.GetPassenger
function ENT:GetPilot()
  return self:GetPassenger(1)
end

--- Get the player from a specific seat.
-- @shared
-- @param index String or number index of the seat
-- @treturn player The found `Player` or `NULL`
function ENT:GetPassenger(index)
  local seat = self:GetSeat(index)

  if not IsValid(seat) then return NULL end

  if SERVER then
    return seat:GetDriver()
  else
    return seat:GetNWEntity("Driver", NULL)
  end
end

function ENT:PlaySound(path, callback, options)
  if CLIENT then
    self.LoadedSounds = self.LoadedSounds or {}
  end

  local sound, filter

  if SERVER then
    filter = RecipientFilter()

    for _, ply in ipairs(player.GetAll()) do
      if callback(self, ply) then filter:AddPlayer(ply) end
    end
  end

  if SERVER or not self.LoadedSounds[path] then
    sound = CreateSound(self, path, filter)

    if sound then
      sound:SetSoundLevel(options.Level or 0)

      if CLIENT then
        self.LoadedSounds[path] = sound
      end
    end
  else
    sound = self.LoadedSounds[path]
  end

  if sound then
    if CLIENT then sound:Stop() end

    sound:PlayEx(options.Volume or 1, options.Pitch or 100)
  end

  return sound
end

--- Networking
-- @section networking

local EVENTS = {
  "CanEnter",
  "OnEnter",
  "OnExit",
  "OnEngineStart",
  "OnEngineStop",
  "OnEngineStartup",
  "OnEngineShutdown",
  "OnLand",
  "OnTakeoff",
  "OnCollide",
  "PrimaryAttack",
  "SecondaryAttack",
  "AlternateFire",
  "GunnerPrimaryAttack",
  "GunnerSecondaryAttack",
  "GunnerAlternateFire",
  "OnShieldDamage"
}

local EVENTS_TABLE = {}

for i, evt in ipairs(EVENTS) do
  EVENTS_TABLE[i] = string.upper(evt)
end

--- Dispatch a networked event to all clients.
-- @server
-- @string event The event to dispatch
-- @param ... Any arguments to network
function ENT:DispatchNWEvent(event, ...)
  if CLIENT then return true, false end

  local cancel, result = self:DispatchEvent(event, ...)

  if cancel then return true, false end

  -- Network the event clientside
  net.Start("SWVR.EventDispatcher")

  local index = table.KeyFromValue(EVENTS_TABLE, string.upper(event))

  net.WriteUInt(index, 6)
  net.WriteEntity(self)
  net.WriteTable({...})

  net.Broadcast()

  return false, result
end

--- Dispatch an event only client/server side.
-- @shared
-- @string event The event to dispatch
-- @param ... Any arguments to send
-- @treturn bool If the event was stopped by a hook
-- @return The result from the hook
function ENT:DispatchEvent(event, ...)
  self.EventDispatcher = self.EventDispatcher or {}
  self.EventDispatcher[string.upper(event)] = self.EventDispatcher[string.upper(event)] or {}

  -- First we run hooks, they are top priority
  local result = hook.Run("SWVR." .. event, self, ...)

  -- If any hook returned false, stop the event from propogating
  if result == false then return true, false end

  -- Now check for our own event server/client side
  if self[event] ~= nil then
    self[event](self, ...)
  end

  -- Run server/client side added callbacks to this event
  for k, v in pairs(self.EventDispatcher[string.upper(event)] or {}) do
    v(self, ...)
  end

  return false, result
end

--- Add a callback to an event.
-- @shared
-- @string name The name of the event
-- @func callback The callback to run on the event
function ENT:AddEvent(name, callback)
  self.EventDispatcher = self.EventDispatcher or {}
  self.EventDispatcher[string.upper(name)] = self.EventDispatcher[string.upper(name)] or {}

  table.insert(self.EventDispatcher[string.upper(name)], callback or function() return end)
end

--- Get the callbacks for an event.
-- @shared
-- @string event The name of the event
-- @treturn table Table of callback functions
function ENT:GetEvents(event)
  self.EventDispatcher = self.EventDispatcher or {}

  if isstring(event) then
    return self.EventDispatcher[string.upper(event)] or {}
  end

  return self.EventDispatcher
end

function ENT:SetCooldown(action, time)
  self.Cooldowns = self.Cooldowns or {}

  if not action then return end

  if SERVER then
    net.Start("SWVR.Cooldown")
      net.WriteEntity(self)
      net.WriteString(util.Compress(action))
      net.WriteFloat(time)
    net.Broadcast()
  end

  self.Cooldowns[action] = time
end

function ENT:GetCooldown(action)
  self.Cooldowns = self.Cooldowns or {}

  return self.Cooldowns[action]
end

-- NETWORKING

if CLIENT then
  net.Receive("SWVR.EventDispatcher", function()

    local index = net.ReadUInt(6)
    local ent = net.ReadEntity()
    local data = net.ReadTable()

    if not (IsValid(ent) and ent.IsSWVRVehicle) then return end

    ent:DispatchEvent(EVENTS[index], unpack(data))
  end)

  net.Receive("SWVR.Cooldown", function()
    local ent = net.ReadEntity()
    local action = util.Decompress(net.ReadString())
    local time = net.ReadFloat()

    if not IsValid(ent) then return end
    if not ent.SetCooldown then return end

    ent:SetCooldown(action, time)
  end)
end

if SERVER then
  util.AddNetworkString("SWVR.EventDispatcher")
  util.AddNetworkString("SWVR.Cooldown")
end
