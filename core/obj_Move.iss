objectdef obj_Move inherits obj_StateQueue
{
	variable obj_Approach ApproachModule

	variable bool Traveling = FALSE
	variable int GateMoveModuleCounter


	method Initialize()
	{
		This[parent]:Initialize
		This.NonGameTiedPulse:Set[TRUE]
	}

	method Warp(int64 ID, int Dist=0, bool FleetWarp=FALSE)
	{
		if ${Me.Fleet.IsMember[${Me.CharID}]}
		{
			if (${Me.ToFleetMember.IsFleetCommander} || \
				${Me.ToFleetMember.IsWingCommander} || \
				${Me.ToFleetMember.IsSquadCommander}) && \
				${FleetWarp}
			{
				Entity[${ID}]:WarpFleetTo[${Dist}]
			}
			else
			{
				Entity[${ID}]:WarpTo[${Dist}]
			}
		}
		else
		{
			Entity[${ID}]:WarpTo[${Dist}]
		}
		; Don't pause the combat bot when fleeing but before warp start
		; Client:Wait[5000]
	}

	method ActivateAutoPilot()
	{
		if !${Me.AutoPilotOn}
		{
			Logger:Log["Move", "Activating autopilot", "o"]
			EVE:Execute[CmdToggleAutopilot]
		}
	}

	method TravelToSystem(int64 DestinationSystemID)
	{
		if ${Me.ToEntity.Mode} == MOVE_WARPING || ${DestinationSystemID.Equal[${Me.SolarSystemID}]} || ${Me.AutoPilotOn}
		{
			return
		}

		variable index:int DestinationList
		EVE:GetWaypoints[DestinationList]

		if ${DestinationList[${DestinationList.Used}]} != ${DestinationSystemID}
		{
			Logger:Log["Move", "Setting destination", "o"]
			Logger:Log["Move", " ${Universe[${DestinationSystemID}].Name}", "-g"]
			Universe[${DestinationSystemID}]:SetDestination
			return
		}

		This:ActivateAutoPilot
	}

	method TravelToStation(int64 StationID)
	{
		if ${Me.ToEntity.Mode} == MOVE_WARPING || ${Me.AutoPilotOn}
		{
			return
		}

		variable index:int DestinationList
		EVE:GetWaypoints[DestinationList]

		if ${EVE.Station[${StationID}].SolarSystem.ID} == ${Me.SolarSystemID}
		{
			This:DockAtStation[${StationID}]
			return
		}

		if ${DestinationList[${DestinationList.Used}]} != ${EVE.Station[${StationID}].SolarSystem.ID}
		{
			Logger:Log["Move", "Setting destination", "o"]
			Logger:Log["Move", " ${EVE.Station[${StationID}].Name}", "-g"]
			Universe[${EVE.Station[${StationID}].SolarSystem.ID}]:SetDestination
			return
		}

		This:ActivateAutoPilot
	}

	method Undock()
	{
		EVE:Execute[CmdExitStation]
		Client:Wait[12000]
	}

	method DockAtStation(int64 StationID)
	{
		if ${Entity[${StationID}](exists)}
		{
			Logger:Log["Move", "Docking", "o"]
			Logger:Log["Move", " ${Entity[${StationID}].Name}", "-g"]
			Entity[${StationID}]:Dock
			Client:Wait[10000]
		}
		else
		{
			Logger:Log["Move", "Station Requested does not exist", "r"]
			Logger:Log["Move", "StationID: ${StationID}", "r"]
		}
	}


	method Fleetmember(int64 ID, bool IgnoreGate=FALSE, int Distance=0)
	{
		if ${This.Traveling}
		{
			return
		}

		if !${Me.Fleet.Member[${ID}](exists)}
		{
			Logger:Log["Move", "Fleet member does not exist", "r"]
			Logger:Log["Move", "Fleet member CharID: ${ID}", "r"]
			return
		}

		Logger:Log["Move", "Movement queued", "o"]
		Logger:Log["Move", " ${Being[${ID}].Name}", "-g"]
		This.Traveling:Set[TRUE]
		This:QueueState["FleetmemberMove", 2000, "${ID}, ${IgnoreGate}, ${Distance}"]
	}

	method Bookmark(string DestinationBookmarkLabel, bool IgnoreGate=FALSE, int Distance=0, bool FleetWarp=FALSE)
	{
		if ${This.Traveling}
		{
			return
		}

		if !${EVE.Bookmark[${DestinationBookmarkLabel}](exists)} && !${EVE.Station[${DestinationBookmarkLabel}](exists)}
		{
			Logger:Log["Move", "Attempted to travel to a bookmark which does not exist", "r"]
			Logger:Log["Move", "Bookmark label: ${DestinationBookmarkLabel}", "r"]
			return
		}

		if ${EVE.Bookmark[${DestinationBookmarkLabel}](exists)}
		{
			Logger:Log["Move", "Movement queued", "o"]
			Logger:Log["Move", " ${DestinationBookmarkLabel}", "-g"]
		}
		if ${EVE.Station[${DestinationBookmarkLabel}](exists)}
		{
			Logger:Log["Move", "Movement queued", "o"]
			Logger:Log["Move", " ${EVE.Station[${DestinationBookmarkLabel}].Name}", "-g"]
		}
		This.Traveling:Set[TRUE]
		This:QueueState["BookmarkMove", 2000, "${DestinationBookmarkLabel}, ${IgnoreGate}, ${Distance}, ${FleetWarp}"]
	}

	method AgentBookmark(int64 destinationID)
	{
		if ${This.Traveling}
		{
			return
		}

		variable index:agentmission Missions
		variable iterator m

		EVE:GetAgentMissions[Missions]
		Missions:GetIterator[m]
		if ${m:First(exists)}
			do
			{
				variable index:bookmark missionBookmarks
				variable iterator b
				m.Value:GetBookmarks[missionBookmarks]
				missionBookmarks:GetIterator[b]
				if ${b:First(exists)}
					do
					{
						if ${b.Value.ID} == ${destinationID}
						{
							if ${b.Value.LocationType.Equal[dungeon]}
							{
								if ${Client.InSpace} && (${Entity[Type = "Beacon"]} || ${Entity[Type = "Acceleration Gate"]})
								{
									Logger:Log["Move", "Appear to already be in a dungeon", "o"]
									return
								}
							}
							Logger:Log["Move", "Movement queued", "o"]
							Logger:Log["Move", " ${b.Value.Label}", "-g"]
						}
					}
					while ${b:Next(exists)}
			}
			while ${m:Next(exists)}
		else
		{
			Logger:Log["Move", "Attempted to travel to an agent bookmark which does not exist", "r"]
			Logger:Log["Move", "Bookmark ID: ${destinationID}", "r"]
			return
		}


		This.Traveling:Set[TRUE]
		This:QueueState["AgentBookmarkMove", 2000, "${destinationID}"]
	}

	method System(string SystemID)
	{
		if ${This.Traveling}
		{
			return
		}

		if !${Universe[${SystemID}](exists)}
		{
			Logger:Log["Move", "Attempted to travel to a system which does not exist", "r"]
			Logger:Log["Move", "System ID: ${SystemID}", "r"]
			return
		}

		Logger:Log["Move", "Movement queued", "o"]
		Logger:Log["Move", " ${Universe[${SystemID}].Name}", "-g"]
		This.Traveling:Set[TRUE]
		This:QueueState["SystemMove", 2000, ${SystemID}]
	}

	method Entity(int64 ID, int Distance=0, bool FleetWarp=FALSE)
	{
		if ${This.Traveling}
		{
			return
		}

		Logger:Log["Move", "Movement queued", "o"]
		Logger:Log["Move", " ${Entity[${ID}].Name}", "-g"]
		This.Traveling:Set[TRUE]
		Entity[${ID}]:AlignTo
		This:QueueState["EntityMove", 2000, "${ID}, ${Distance}, ${FleetWarp}"]
	}

	method Agent(string AgentName)
	{
		if !${EVE.Agent[${AgentName}](exists)}
		{
			Logger:Log["Move", "Attempted to travel to an agent which does not exist", "r"]
			Logger:Log["Move", "Agent name: ${AgentName}", "r"]
			return
		}

		This:Agent[${EVE.Agent[${AgentName}].Index}]
	}

	method Agent(int AgentIndex)
	{
		if ${This.Traveling}
		{
			return
		}

		if !${EVE.Agent[${AgentIndex}](exists)}
		{
			Logger:Log["Move", "Attempted to travel to an agent which does not exist", "r"]
			Logger:Log["Move", "Agent index: ${AgentIndex}", "r"]
			return
		}

		Logger:Log["Move", "Movement queued", "o"]
		Logger:Log["Move", " ${EVE.Agent[${AgentIndex}].Name}", "-g"]
		This.Traveling:Set[TRUE]
		This:InsertState["AgentMove", 2000, ${AgentIndex}]
	}

	method Gate(int64 ID, bool CalledFromMove=FALSE)
	{
		Logger:Log["Move", "Movement queued", "o"]
		Logger:Log["Move", " ${Entity[${ID}].Name}", "-g"]
		This.Traveling:Set[TRUE]
		This:QueueState["GateMove", 2000, "${ID}, ${CalledFromMove}"]
	}

	member:bool GateMove(int64 ID, bool CalledFromMove)
	{
		;GateMoveModuleCounter:Inc[1]
		; If the gate doesn't exist, or it is locked, bail out.
		if !${Entity[${ID}](exists)} || ${EVEWindow[byName, modal].Text.Find[This gate is locked!]} || ${EVEWindow[byName, modal].Text.Find[permit]} || ${EVEWindow[byName, modal].Text.Find[key]}
		{
			if !${CalledFromMove}
			{
				This.Traveling:Set[FALSE]
			}
			;GateMoveModuleCounter:Set[0]
			return TRUE
		}
		; Not sure why this is here, we shouldn't be able to end up here if we are already in warp.
		if ${Me.ToEntity.Mode} == MOVE_WARPING
		{
			return FALSE
		}
		; We are too close to the gate, orbit it so we don't get stuck on it. This might have worked in the past? You can't get a negative distance anymore.
		if ${Entity[${ID}].Distance} < -8000
		{
			Logger:Log["Move", "Too close!  Orbiting ${Entity[${ID}].Name}", "g"]
			Entity[${ID}]:Orbit
			Client:Wait[10000]
			return FALSE
		}
		;	We seem to have been approaching for a long time, lets stop the ship and exit the approach.
		;if ${GateMoveModuleCounter} > 30
		;{
		;	Logger:Log["Move", "Approaching for too long, abort]
		;	EVE:Execute[CmdStopShip]
		;	GateMoveModuleCounter:Set[0]
		;	return TRUE
		;}
		; If the gate is too far away, we approach.
		if ${Entity[${ID}].Distance} >= 2500
		{
			This:Approach[${ID}, 2500]
			return FALSE
		}
		; We are in range, activate the gate.
		Logger:Log["Move", "Activating ${Entity[${ID}].Name}", "g"]
		Entity[${ID}]:Activate
		Client:Wait[5000]
		if !${CalledFromMove}
		{
			This.Traveling:Set[FALSE]
		}
		return FALSE
	}

	member:bool FleetmemberMove(int64 ID, bool IgnoreGate=FALSE, int Distance=0)
	{
		if !${Me.Fleet.Member[${ID}].ToPilot(exists)}
		{
			Logger:Log["Move", "Fleet member ${Being[${ID}].Name} is no longer in local, canceling Move", "g"]
			This.Traveling:Set[FALSE]
			return TRUE
		}

		if ${Me.InStation}
		{
			Logger:Log["Move", "Undocking", "o"]
			Logger:Log["Move", " ${Me.Station.Name}", "-g"]
			This:Undock
			return FALSE
		}

		if !${Client.InSpace}
		{
			return FALSE
		}

		if ${Me.ToEntity.Mode} == MOVE_WARPING
		{
			return FALSE
		}

		if ${Me.Fleet.Member[${ID}].ToEntity(exists)}
		{
			if ${Me.Fleet.Member[${ID}].ToEntity.Distance} > 100000
			{

				Logger:Log["Move", "Bounce warping", "o"]
				Logger:Log["Move", " ${Entity[ID >= 40000000 && ID <= 50000000].Name}", "-g"]
				Entity[ID >= 40000000 && ID <= 50000000]:WarpTo
				Client:Wait[5000]
				return FALSE
			}
			else
			{
				Logger:Log["Move", "Reached \ao${Me.Fleet.Member[${ID}].ToPilot.Name}", "g"]
				This.Traveling:Set[FALSE]
				return TRUE
			}
		}
		else
		{
				if ${Entity["GroupID = GROUP_WARPGATE"](exists)} && !${IgnoreGate}
				{
					Logger:Log["Move", "Gate found, activating", "g"]
					This:Gate[${Entity["GroupID = GROUP_WARPGATE"].ID}, TRUE]
					This:QueueState["FleetmemberMove", 2000, ${ID}]
					return TRUE
				}
				Logger:Log["Move", "Warping", "o"]
				Logger:Log["Move", " ${Me.Fleet.Member[${ID}].ToPilot.Name}", "-g"]
				Me.Fleet.Member[${ID}]:WarpTo[${Distance}]
				Client:Wait[5000]
				This:QueueState["FleetmemberMove", 2000, "${ID}, FALSE, ${Distance}"]

				return TRUE
		}
	}

	member:bool BookmarkMove(string Bookmark, bool IgnoreGate=FALSE, int Distance=0, bool FleetWarp=FALSE)
	{

		if ${Me.InStation}
		{
			if ${EVE.Bookmark[${Bookmark}](exists)}
			{
				if ${Me.StationID} == ${EVE.Bookmark[${Bookmark}].ItemID}
				{
					Logger:Log["Move", "Docked", "o"]
					Logger:Log["Move", " ${Bookmark}", "-g"]
					This.Traveling:Set[FALSE]
					return TRUE
				}
				else
				{
					Logger:Log["Move", "Undocking", "o"]
					Logger:Log["Move", " ${Me.Station.Name}", "-g"]
					This:Undock
					return FALSE
				}
			}
			if ${EVE.Station[${Bookmark}](exists)}
			{
				if ${Me.StationID} == ${Bookmark}
				{
					Logger:Log["Move", "Docked", "o"]
					Logger:Log["Move", " ${EVE.Station[${Bookmark}].Name}", "-g"]
					This.Traveling:Set[FALSE]
					return TRUE
				}
				else
				{
					Logger:Log["Move", "Undocking", "o"]
					Logger:Log["Move", " ${Me.Station.Name}", "-g"]
					This:Undock
					return FALSE
				}
			}
		}

		if !${Client.InSpace}
		{
			return FALSE
		}

		if ${Me.ToEntity.Mode} == MOVE_WARPING
		{
			return FALSE
		}

		if ${EVE.Bookmark[${Bookmark}](exists)}
		{
			if ${EVE.Bookmark[${Bookmark}].SolarSystemID} != ${Me.SolarSystemID}
			{
				This:TravelToSystem[${EVE.Bookmark[${Bookmark}].SolarSystemID}]
				return FALSE
			}
		}
		if ${EVE.Station[${Bookmark}](exists)}
		{
			This:TravelToStation[${Bookmark}]
		}

		if ${EVE.Bookmark[${Bookmark}].ItemID} == -1
		{
			if ${EVE.Bookmark[${Bookmark}].Distance} > 150000
			{
				if ${Entity["GroupID = GROUP_WARPGATE"](exists)} && !${IgnoreGate}
				{
					Logger:Log["Move", "Gate found, activating", "g"]
					This:Gate[${Entity["GroupID = GROUP_WARPGATE"].ID}, TRUE]
					This:QueueState["BookmarkMove", 2000, ${Bookmark}]
					return TRUE
				}

				Logger:Log["Move", "Warping", "o"]
				Logger:Log["Move", " ${Bookmark}", "-g"]
				if ${Me.Fleet.IsMember[${Me.CharID}]}
				{
					if (${Me.ToFleetMember.IsFleetCommander} || \
						${Me.ToFleetMember.IsWingCommander} || \
						${Me.ToFleetMember.IsSquadCommander}) && \
						${FleetWarp}
					{
						EVE.Bookmark[${Bookmark}]:WarpFleetTo[${Distance}]
					}
					else
					{
						EVE.Bookmark[${Bookmark}]:WarpTo[${Distance}]
					}
				}
				else
				{
					EVE.Bookmark[${Bookmark}]:WarpTo[${Distance}]
				}
				Client:Wait[5000]
				This:QueueState["BookmarkMove", 2000, ${Bookmark}]
				return TRUE
			}
			elseif ${EVE.Bookmark[${Bookmark}].Distance} != -1 && ${EVE.Bookmark[${Bookmark}].Distance(exists)}
			{
				Logger:Log["Move", "Reached", "o"]
				Logger:Log["Move", " ${Bookmark}", "-g"]
				This.Traveling:Set[FALSE]
				return TRUE
			}
			else
			{
				return FALSE
			}
		}
		else
		{
			if ${EVE.Bookmark[${Bookmark}].ToEntity(exists)}
			{
				if ${EVE.Bookmark[${Bookmark}].ToEntity.Distance} > 150000
				{
					Logger:Log["Move", "Warping", "o"]
					Logger:Log["Move", " ${Bookmark}", "-g"]
					if ${Me.Fleet.IsMember[${Me.CharID}]}
					{
						if (${Me.ToFleetMember.IsFleetCommander} || \
							${Me.ToFleetMember.IsWingCommander} || \
							${Me.ToFleetMember.IsSquadCommander}) && \
							${FleetWarp}
						{
							EVE.Bookmark[${Bookmark}].ToEntity:WarpFleetTo[${Distance}]
						}
						else
						{
							EVE.Bookmark[${Bookmark}].ToEntity:WarpTo[${Distance}]
						}
					}
					else
					{
						EVE.Bookmark[${Bookmark}].ToEntity:WarpTo[${Distance}]
					}
					return FALSE
				}
				elseif ${EVE.Bookmark[${Bookmark}].ToEntity.Distance} != -1 && ${EVE.Bookmark[${Bookmark}].ToEntity.Distance(exists)}
				{
					Logger:Log["Move", "Docking", "o"]
					Logger:Log["Move", " ${Bookmark}", "-g"]
					This:DockAtStation[${EVE.Bookmark[${Bookmark}].ItemID}]
					return FALSE
				}
				else
				{
					return FALSE
				}
			}
			else
			{
				if ${EVE.Bookmark[${Bookmark}].Distance} > 150000
				{
					Logger:Log["Move", "Warping", "o"]
					Logger:Log["Move", " ${Bookmark}", "-g"]
					if ${Me.Fleet.IsMember[${Me.CharID}]}
					{
						if (${Me.ToFleetMember.IsFleetCommander} || \
							${Me.ToFleetMember.IsWingCommander} || \
							${Me.ToFleetMember.IsSquadCommander}) && \
							${FleetWarp}
						{
							EVE.Bookmark[${Bookmark}]:WarpFleetTo[${Distance}]
						}
						else
						{
							EVE.Bookmark[${Bookmark}]:WarpTo[${Distance}]
						}
					}
					else
					{
						EVE.Bookmark[${Bookmark}]:WarpTo[${Distance}]
					}
					Client:Wait[5000]
					return FALSE
				}
				elseif ${EVE.Bookmark[${Bookmark}].Distance} != -1 && ${EVE.Bookmark[${Bookmark}].Distance(exists)}
				{
					Logger:Log["Move", "Reached", "o"]
					Logger:Log["Move", " ${Bookmark}", "-g"]
					This.Traveling:Set[FALSE]
					return TRUE
				}
				else
				{
					return FALSE
				}
			}
		}
	}

	member:bool AgentBookmarkMove(int64 destinationID)
	{
		variable index:agentmission Missions
		variable iterator m

		EVE:GetAgentMissions[Missions]
		Missions:GetIterator[m]
		if ${m:First(exists)}
			do
			{
			variable index:bookmark missionBookmarks
			variable iterator b
			m.Value:GetBookmarks[missionBookmarks]
			missionBookmarks:GetIterator[b]
			if ${b:First(exists)}
				do
				{
					if ${b.Value.ID} == ${destinationID}
					{
						if ${Me.InStation}
						{
							if ${Me.StationID} == ${b.Value.ItemID}
							{
								Logger:Log["Move", "Docked", "o"]
								Logger:Log["Move", " ${Me.Station.Name}", "-g"]
								This.Traveling:Set[FALSE]
								return TRUE
							}
							else
							{
								Logger:Log["Move", "Undocking", "o"]
								Logger:Log["Move", " ${Me.Station.Name}", "-g"]
								This:Undock
								return FALSE
							}
						}
						if !${Client.InSpace} || ${Me.ToEntity.Mode} == MOVE_WARPING
							return FALSE
						if ${b.Value.SolarSystemID} != ${Me.SolarSystemID}
						{
							This:TravelToSystem[${b.Value.SolarSystemID}]
							return FALSE
						}
						if ${b.Value.ItemID} == -1
						{
							if ${b.Value.Distance} > 150000
							{
								Logger:Log["Move", "Warping", "o"]
								Logger:Log["Move", " ${b.Value.Label}", "-g"]

								b.Value:WarpTo[0]
								Client:Wait[5000]
								This:QueueState["AgentBookmarkMove", 2000, ${destinationID}]
								return TRUE
							}
							elseif ${b.Value.Distance} != -1 && ${b.Value.Distance(exists)}
							{
								Logger:Log["Move", "Reached", "o"]
								Logger:Log["Move", " ${b.Value.Label}", "-g"]
								This.Traveling:Set[FALSE]
								return TRUE
							}
							else
							{
								return FALSE
							}
						}
						else
						{
							if ${b.Value.ToEntity(exists)}
							{
								if ${b.Value.ToEntity.Distance} > 150000
								{
									Logger:Log["Move", "Warping", "o"]
									Logger:Log["Move", " ${b.Value.Label}", "-g"]

									b.Value.ToEntity:WarpTo[0]
									return FALSE
								}
								elseif ${b.Value.ToEntity.Distance} != -1 && ${b.Value.ToEntity.Distance(exists)}
								{
									Logger:Log["Move", "Docking", "o"]
									Logger:Log["Move", " ${b.Value.Label}", "-g"]
									This:DockAtStation[${b.Value.ItemID}]
									return FALSE
								}
								else
								{
									return FALSE
								}
							}
							else
							{
								if ${b.Value.LocationType.Equal[dungeon]}
								{
									if ${Client.InSpace} && (${Entity[Type = "Beacon"]} || ${Entity[Type = "Acceleration Gate"]})
									{
										Logger:Log["Move", "Appear to already be in a dungeon", "o"]
										This.Traveling:Set[FALSE]
										return TRUE
									}
								}
								if ${b.Value.Distance} > 150000
								{
									Logger:Log["Move", "Warping", "o"]
									Logger:Log["Move", " ${b.Value.Label}", "-g"]

									b.Value:WarpTo[0]
									Client:Wait[5000]
									return FALSE
								}
								elseif ${b.Value.Distance} != -1 && ${b.Value.Distance(exists)}
								{
									Logger:Log["Move", "Reached", "o"]
									Logger:Log["Move", " ${b.Value.Label}", "-g"]
									This.Traveling:Set[FALSE]
									return TRUE
								}
								else
								{
									return FALSE
								}
							}
						}
					}
				}
				while ${b:Next(exists)}
			}
			while ${m:Next(exists)}
	}

	member:bool AgentMove(int ID)
	{
		if ${Me.InStation}
		{
			if ${Me.StationID} == ${EVE.Agent[${ID}].StationID}
			{
				Logger:Log["Move", "Docked", "o"]
				Logger:Log["Move", " ${Me.Station.Name}", "-g"]
				This.Traveling:Set[FALSE]
				return TRUE
			}
			else
			{
				Logger:Log["Move", "Undocking", "o"]
				Logger:Log["Move", " ${Me.Station.Name}", "-g"]
				This:Undock
				return FALSE
			}
		}

		if ${Me.ToEntity.Mode} == MOVE_WARPING || !${Client.InSpace}
		{
			return FALSE
		}

		if ${EVE.Agent[${ID}].Solarsystem.ID} != ${Me.SolarSystemID}
		{
			This:TravelToSystem[${EVE.Agent[${ID}].Solarsystem.ID}]
			return FALSE
		}

		if ${Entity[${EVE.Agent[${ID}].StationID}](exists)}
		{
			if ${Entity[${EVE.Agent[${ID}].StationID}].Distance} > 150000
			{
				Logger:Log["Move", "Warping", "o"]
				Logger:Log["Move", " ${EVE.Agent[${ID}].Station}", "-g"]
				This:Warp[${EVE.Agent[${ID}].StationID}]
				return FALSE
			}
			else
			{
				Logger:Log["Move", "Docking", "o"]
				Logger:Log["Move", " ${EVE.Agent[${ID}].Station}", "-g"]
				This:DockAtStation[${EVE.Agent[${ID}].StationID}]
				return FALSE
			}
		}
	}

	member:bool SystemMove(int64 ID)
	{
		if ${Me.InStation}
		{
			if ${Me.SolarSystemID} == ${ID}
			{
				Logger:Log["Move", "Reached ${Universe[${ID}].Name}", "g"]
				This.Traveling:Set[FALSE]
				return TRUE
			}
			else
			{
				Logger:Log["Move", "Undocking", "o"]
				Logger:Log["Move", " ${Me.Station.Name}", "-g"]
				This:Undock
				return FALSE
			}
		}

		if !${Client.InSpace}
		{
			return FALSE
		}

		if ${Me.ToEntity.Mode} == MOVE_WARPING
		{
			return FALSE
		}

		if ${ID} != ${Me.SolarSystemID}
		{
			This:TravelToSystem[${ID}]
			return FALSE
		}
		This.Traveling:Set[FALSE]
		return TRUE
	}

	; TODO leverage this method elsewhere
	; TODO replace autopilot with this method with cloak-warp trick
	member:bool EntityMove(int64 ID, int Distance=0, bool FleetWarp=FALSE)
	{
		if ${Me.InStation}
		{
			if ${Me.StationID} == ${ID}
			{
				Logger:Log["Move", "Docked", "o"]
				Logger:Log["Move", " ${Me.Station.Name}", "-g"]
				This.Traveling:Set[FALSE]
				return TRUE
			}
			Logger:Log["Move", "Undocking", "o"]
			Logger:Log["Move", " ${Me.Station.Name}", "-g"]
			This:Undock
			return FALSE
		}

		if ${Me.ToEntity.Mode} == MOVE_WARPING || !${Client.InSpace}
		{
			return FALSE
		}

		if !${Entity[${ID}](exists)}
		{
			Logger:Log["Move", "Attempted to warp to object ${ID} which does not exist", "r"]
		}

		if ${Entity[${ID}].Distance} > 150000
		{
			Entity[${ID}]:AlignTo
			This:Warp[${ID}, ${Distance}, ${FleetWarp}]
			return FALSE
		}
		elseif ${Entity[${ID}].CategoryID} == CATEGORYID_STATION || ${Entity[${ID}].CategoryID} == CATEGORYID_STRUCTURE
		{
			This:DockAtStation[${ID}]
			return FALSE
		}

		This.Traveling:Set[FALSE]
		return TRUE
	}


	method Approach(int64 ID, int distance=0)
	{
		;	If we're already approaching the target, ignore the request
		if !${ApproachModule.IsIdle}
		{
			return
		}
		if !${Entity[${ID}](exists)}
		{
			Logger:Log["Move", "Attempted to approach a target that does not exist", "r"]
			Logger:Log["Move", "Target ID: ${ID}", "r"]
			return
		}
		if ${Entity[${ID}].Distance} <= ${distance}
		{
			return
		}

		ApproachModule:QueueState["CheckApproach", 1000, "${ID}, ${distance}"]
	}


	method Orbit(int64 ID, int distance=0)
	{
		if ${Me.ToEntity.Mode} == MOVE_WARPING || !${Entity[${ID}](exists)}
			return

		;	Find out if we need to approach the target
		if ${Me.ToEntity.Mode} != MOVE_ORBITING || ${orbitTarget} != ${ID}
		{
			Logger:Log["Move", "Orbiting ${Entity[${ID}].Name} at ${Tehbot.MetersToKM_Str[${distance}]}", "g"]
			Entity[${ID}]:Orbit[${distance}]
			orbitTarget:Set[${ID}]
			return
		}
	}

	method SaveSpot()
	{
		Logger:Log["Move", "Storing current location", "y"]
		This.SavedSpot:Set["Saved Spot ${EVETime.Time.Left[-3]}"]
		EVE:CreateBookmark["${This.SavedSpot}","","",1]
	}

	member:bool SavedSpotExists()
	{
		if ${This.SavedSpot.Length} > 0
		{
			return ${EVE.Bookmark["${This.SavedSpot}"](exists)}
		}
		return FALSE
	}

	method RemoveSavedSpot()
	{
		if ${This.SavedSpotExists}
		{
			EVE.Bookmark["${This.SavedSpot}"]:Remove
			SavedSpot:Set[""]
		}
	}

	method GotoSavedSpot()
	{
		if ${This.SavedSpotExists}
		{
			This:Bookmark["${This.SavedSpot}"]
		}
	}

	method Stop()
	{
		Logger:Log["Move", "Stopping."]
		This.Traveling:Set[FALSE]
		This:Clear
	}

}

objectdef obj_Approach inherits obj_StateQueue
{
	variable int ApproachModuleCounter

	method Initialize()
	{
		This[parent]:Initialize
		This.PulseFrequency:Set[1000]
		This.NonGameTiedPulse:Set[TRUE]
	}


	member:bool CheckApproach(int64 ID, int distance)
	{
		;ApproachModuleCounter:Inc[1]
		Logger:Log["Move", "DEBUG - We are in the approach state - Iteration Number ${ApproachModuleCounter}"]
		;	Clear approach if we're in warp or the entity no longer exists
		if ${Me.ToEntity.Mode} == MOVE_WARPING || !${Entity[${ID}](exists)}
		{
			return TRUE
			Logger:Log["Move", "This thing we are approaching doesn't exist"]
		}
		
		;; MJD usage, if the gate is further than 60k lets try to MJD to it
		if (${Entity[${ID}].Distance} > 60000 && ${Ship.ModuleList_MJD.Count} > 0) && (${DimensionalNavigation.InvokeTimer} < ${LavishScript.RunningTime}) && !${DimensionalNavigation.MJDInProgress}
		{
			This:LogInfo["We are preparing for an MJD Activation - MOVE "]
			DimensionalNavigation:InvokeMJD[0, 0, 0, ${ID}, FALSE]
		}
		
		;	We seem to have been approaching for a long time, lets stop the ship and exit the approach.
		;if ${ApproachModuleCounter} > 30
		;{
		;	Logger:Log["Move", "Approaching for too long, abort]
		;	EVE:Execute[CmdStopShip]
		;	ApproachModuleCounter:Set[0]
		;	return TRUE
			
		;}
		;	Find out if we need to approach the target
		if ${Entity[${ID}].Distance} >= ${distance} && ${Me.ToEntity.Mode} != MOVE_APPROACHING
		{
			Logger:Log["Move", "Approaching to within ${Tehbot.MetersToKM_Str[${distance}]} of ${Entity[${ID}].Name}", "g"]
			Entity[${ID}]:Approach[${distance}]
			ApproachModuleCounter:Set[0]
			return FALSE
		}

		;	If we're approaching a target, find out if we need to stop doing so
		if ${Entity[${ID}].Distance} < ${distance} && ${Me.ToEntity.Mode} == MOVE_APPROACHING
		{
			Logger:Log["Move", "Within ${Tehbot.MetersToKM_Str[${distance}]} of ${Entity[${ID}].Name}", "g"]
			EVE:Execute[CmdStopShip]
			Ship.ModuleList_AB_MWD:DeactivateAll
			ApproachModuleCounter:Set[0]
			return TRUE
		}
		return FALSE
	}
}
