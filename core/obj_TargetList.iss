variable set OwnedTargets
variable collection:int TargetList_DeadDelay

objectdef obj_TargetList inherits obj_StateQueue
{
	variable int64 DistanceTarget
	variable index:entity TargetList
	variable index:entity LockedTargetList
	variable index:entity LockedAndLockingTargetList
	variable int64 ClosestOutOfRange = -1
	variable index:entity TargetListBuffer
	variable index:entity TargetListBufferOOR
	variable index:entity LockedTargetListBuffer
	variable index:entity LockedTargetListBufferOOR
	variable index:entity LockedAndLockingTargetListBuffer
	variable index:entity LockedAndLockingTargetListBufferOOR
	variable set AlreadyInList
	variable index:string QueryStringList
	variable collection:int TargetLockPrioritys
	variable collection:int TargetLockPrioritysBuffer
	variable set ExcludeTargetID
	variable set ExcludeTargetNameIncludeString
	variable set LockedAndLockingTargets
	variable int64 DistanceTarget
	variable int MaxRange = 20000
	variable int MinRange = 0
	variable bool ListOutOfRange = TRUE
	variable bool AutoLock = FALSE
	variable bool LockOutOfRange = TRUE
	variable int MinLockCount = 2
	variable int MaxLockCount = 2
	variable bool NeedUpdate = TRUE
	variable bool Updated = FALSE
	variable bool ForceLockExclusion = FALSE
	variable bool LockTop = FALSE

	method Initialize()
	{
		This[parent]:Initialize
		PulseFrequency:Set[450]
		This.NonGameTiedPulse:Set[TRUE]
		RandomDelta:Set[150]
		This:QueueState["UpdateList"]
		DistanceTarget:Set[${MyShip.ID}]
	}

	method ClearQueryString()
	{
		QueryStringList:Clear
	}

	method AddQueryString(string QueryString)
	{
		QueryStringList:Insert["${QueryString.Escape}"]
		NeedUpdate:Set[TRUE]
	}

	method AddTargetingMe()
	{
		This:AddQueryString["Distance < 150000 && IsTargetingMe && IsNPC && !IsMoribund"]
		NeedUpdate:Set[TRUE]
	}

	method AddPCTargetingMe()
	{
		This:AddQueryString["Distance < 150000 && IsTargetingMe && !IsFleetMember && IsPC && !IsMoribund"]
		NeedUpdate:Set[TRUE]
	}

	method AddAllPC()
	{
		This:AddQueryString["Distance < 300000 && !IsFleetMember && IsPC && !IsMoribund"]
		NeedUpdate:Set[TRUE]
	}

	method AddAllFleetPC()
	{
		This:AddQueryString["Distance < 300000 && IsFleetMember && IsPC && !IsMoribund"]
		NeedUpdate:Set[TRUE]
	}
	method RequestUpdate()
	{
		variable iterator TargetIterator
		TargetList:GetIterator[TargetIterator]
		if ${TargetIterator:First(exists)}
		{
			do
			{
				if !${TargetIterator.Value.ID(exists)}
				{
					TargetList:Remove[${TargetIterator.Key}]
				}
			}
			while ${TargetIterator:Next(exists)}
		}
		TargetList:Collapse

		LockedTargetList:GetIterator[TargetIterator]
		if ${TargetIterator:First(exists)}
		{
			do
			{
				if !${TargetIterator.Value.ID(exists)}
				{
					LockedTargetList:Remove[${TargetIterator.Key}]
				}
			}
			while ${TargetIterator:Next(exists)}
		}
		LockedTargetList:Collapse

		LockedAndLockingTargetList:GetIterator[TargetIterator]
		if ${TargetIterator:First(exists)}
		{
			do
			{
				if !${TargetIterator.Value.ID(exists)}
				{
					LockedAndLockingTargetList:Remove[${TargetIterator.Key}]
				}
			}
			while ${TargetIterator:Next(exists)}
		}
		LockedAndLockingTargetList:Collapse

		NeedUpdate:Set[TRUE]
		Updated:Set[FALSE]
	}

	method AddAllNPCs()
	{
		variable string QueryString="CategoryID = CATEGORYID_ENTITY && IsNPC && !IsMoribund && !("

		; Abyssal switch for ignoring the really distant cans if we aren't using an MTU
		if !${Abyssal.Config.UseMTU}
		{
			QueryString:Concat["TypeID = 49663 ||"]
			QueryString:Concat["TypeID = 49662 ||"]
			QueryString:Concat["TypeID = 49661 ||"]
		}
		;Exclude Groups here
		QueryString:Concat["GroupID = GROUP_CONCORDDRONE ||"]
		QueryString:Concat["GroupID = GROUP_CONVOYDRONE ||"]
		QueryString:Concat["GroupID = GROUP_CONVOY ||"]
		QueryString:Concat["GroupID = GROUP_LARGECOLLIDABLEOBJECT ||"]
		QueryString:Concat["GroupID = GROUP_LARGECOLLIDABLESHIP ||"]
		QueryString:Concat["GroupID = GROUP_SPAWNCONTAINER ||"]
		QueryString:Concat["GroupID = CATEGORYID_ORE ||"]
		QueryString:Concat["GroupID = GROUP_DEADSPACEOVERSEERSSTRUCTURE ||"]
		QueryString:Concat["GroupID = GROUP_LARGECOLLIDABLESTRUCTURE ||"]
		; Somehow the non hostile Orca and Drone ship in the Anomaly mission is in this group
		QueryString:Concat["GroupID = 288 ||"]		
		QueryString:Concat["GroupID = 446 ||"]		
		QueryString:Concat["GroupID = 182 ||"]	
		QueryString:Concat["GroupID = 4028 ||"]
		QueryString:Concat["GroupID = 383 ||"]
		QueryString:Concat["GroupID = 4034 ||"]
		QueryString:Concat["GroupID = 1803 ||"]
		QueryString:Concat["GroupID = 1896 ||"]
		QueryString:Concat["GroupID = 1765 ||"]
		QueryString:Concat["GroupID = 1766 ||"]
		QueryString:Concat["GroupID = 1764 ||"]
		QueryString:Concat["GroupID = 1767 ||"]
		QueryString:Concat["GroupID = 99 ||"]
		QueryString:Concat["TypeID = 48253 ||"]
		QueryString:Concat["TypeID = 54579 ||"]
		QueryString:Concat["TypeID = 54580 ||"]
		QueryString:Concat["GroupID = 1307 ||"]
		QueryString:Concat["GroupID = 4035 ||"]
		QueryString:Concat["GroupID = 1310 ||"]
		QueryString:Concat["GroupID = 1956 ||"]	
		QueryString:Concat["GroupID = 4036 ||"]			
		QueryString:Concat["GroupID = GROUP_ANCIENTSHIPSTRUCTURE ||"]
		QueryString:Concat["GroupID = GROUP_PRESSURESOLO)"]
		

		This:AddQueryString["${QueryString.Escape}"]
	}

	method AddTargetExceptionByID(int64 ID)
	{
		variable iterator RemoveIterator
		ExcludeTargetID:Add[${ID}]
		TargetList:GetIterator[RemoveIterator]
		if ${RemoveIterator:First(exists)}
		{
			do
			{
				if ${RemoveIterator.Value.ID.Equal[${ID}]}
				{
					TargetList:Remove[${RemoveIterator.Key}]
				}
			}
			while ${RemoveIterator:Next(exists)}
		}
		LockedTargetList:GetIterator[RemoveIterator]
		if ${RemoveIterator:First(exists)}
		{
			do
			{
				if ${RemoveIterator.Value.ID.Equal[${ID}]}
				{
					LockedTargetList:Remove[${RemoveIterator.Key}]
				}
			}
			while ${RemoveIterator:Next(exists)}
		}
		LockedAndLockingTargetList:GetIterator[RemoveIterator]
		if ${RemoveIterator:First(exists)}
		{
			do
			{
				if ${RemoveIterator.Value.ID.Equal[${ID}]}
				{
					LockedAndLockingTargetList:Remove[${RemoveIterator.Key}]
				}
			}
			while ${RemoveIterator:Next(exists)}
		}
		if ${Entity[${ID}].IsLockedTarget}
		{
			Entity[${ID}]:UnlockTarget
		}
	}

	method AddTargetExceptionByPartOfName(string namePart)
	{
		variable iterator RemoveIterator
		ExcludeTargetNameIncludeString:Add[${namePart}]
		TargetList:GetIterator[RemoveIterator]
		if ${RemoveIterator:First(exists)}
		{
			do
			{
				if ${RemoveIterator.Value.Name.Find[${namePart}]}
				{
					TargetList:Remove[${RemoveIterator.Key}]
				}
			}
			while ${RemoveIterator:Next(exists)}
		}
		LockedTargetList:GetIterator[RemoveIterator]
		if ${RemoveIterator:First(exists)}
		{
			do
			{
				if ${RemoveIterator.Value.Name.Find[${namePart}]}
				{
					LockedTargetList:Remove[${RemoveIterator.Key}]
				}
			}
			while ${RemoveIterator:Next(exists)}
		}
		LockedAndLockingTargetList:GetIterator[RemoveIterator]
		if ${RemoveIterator:First(exists)}
		{
			do
			{
				if ${RemoveIterator.Value.Name.Find[${namePart}]}
				{
					LockedAndLockingTargetList:Remove[${RemoveIterator.Key}]
					if ${RemoveIterator.Value.IsLockedTarget}
					{
						RemoveIterator.Value:UnlockTarget
					}
				}
			}
			while ${RemoveIterator:Next(exists)}
		}
	}

	method ClearExcludeTarget()
	{
		ExcludeTargetID:Clear
		ExcludeTargetNameIncludeString:Clear
	}
	
	method ClearExcludeTargetID()
	{
		ExcludeTargetID:Clear
	}

	method ClearSpecificExclusion(int64 EntityID)
	{
		if ${ExcludeTargetID.Contains[${EntityID}]}
			ExcludeTargetID:Remove[${EntityID}]
	}
	member:bool UpdateList()
	{
		if !${NeedUpdate} || !${Client.InSpace} || ${Me.ToEntity.Mode} == MOVE_WARPING
		{
			return FALSE
		}

		variable iterator QueryStringIterator
		QueryStringList:GetIterator[QueryStringIterator]

		if ${QueryStringIterator:First(exists)}
		{
			do
			{
				This:QueueState["GetQueryString", 20, "${QueryStringIterator.Value.Escape}, ${Math.Calc[${QueryStringList.Used}-${QueryStringIterator.Key}]}"]
			}
			while ${QueryStringIterator:Next(exists)}
		}

		This:QueueState["PopulateList"]
		if ${AutoLock}
		{
			This:QueueState["ManageLocks"]
		}
		This:QueueState["SetUpdated"]
		This:QueueState["UpdateList"]
		NeedUpdate:Set[FALSE]
		return TRUE
	}

	member:bool SetUpdated()
	{
		Updated:Set[TRUE]
		return TRUE
	}

	member:bool GetQueryString(string QueryString, int Priority = 0)
	{
		variable index:entity entity_index
		variable iterator entity_iterator
		variable iterator excludeNamePartIterator
		variable bool excludeByNameSubstring = FALSE
		if !${Client.InSpace}
		{
			return FALSE
		}
		EVE:QueryEntities[entity_index, "${QueryString.Escape}"]
		entity_index:GetIterator[entity_iterator]
		if ${entity_iterator:First(exists)}
		{
			do
			{
				if ${entity_iterator.Value.IsLockedTarget} || ${entity_iterator.Value.BeingTargeted}
				{
					TargetList_DeadDelay:Set[${entity_iterator.Value.ID}, ${Math.Calc[${LavishScript.RunningTime} + 5000]}]
				}
				if ${entity_iterator.Value.DistanceTo[${DistanceTarget}]} >= ${MinRange}
				{
					break
				}
				else
				{

				}
			}
			while ${entity_iterator:Next(exists)}

			if ${entity_iterator.Value(exists)}
			{
				do
				{
					if ${entity_iterator.Value.IsLockedTarget} || ${entity_iterator.Value.BeingTargeted}
					{
						TargetList_DeadDelay:Set[${entity_iterator.Value.ID}, ${Math.Calc[${LavishScript.RunningTime} + 5000]}]
					}
					if ${entity_iterator.Value.DistanceTo[${DistanceTarget}]} <= ${MaxRange}
					{
						excludeByNameSubstring:Set[FALSE]
						ExcludeTargetNameIncludeString:GetIterator[excludeNamePartIterator]
						if ${excludeNamePartIterator:First(exists)}
						{
							do
							{
								if ${entity_iterator.Value.Name.Find[${excludeNamePartIterator.Value}]}
								{
									excludeByNameSubstring:Set[TRUE]
									break
								}
							}
							while ${excludeNamePartIterator:Next(exists)}
						}
						if !${ExcludeTargetID.Contains[${entity_iterator.Value.ID}]} && \
							!${entity_iterator.Value.Name.Find["CONCORD"]} && \
							!${excludeByNameSubstring} && \
							!${AlreadyInList.Contains[${entity_iterator.Value.ID}]}
						{
							This.TargetListBuffer:Insert[${entity_iterator.Value.ID}]
							AlreadyInList:Add[${entity_iterator.Value.ID}]
							TargetLockPrioritysBuffer:Set[${entity_iterator.Value.ID}, ${Priority}]
							if ${entity_iterator.Value.IsLockedTarget}
							{
								This.LockedTargetListBuffer:Insert[${entity_iterator.Value.ID}]
								This.LockedAndLockingTargetListBuffer:Insert[${entity_iterator.Value.ID}]
								TargetLockPrioritysBuffer:Set[${entity_iterator.Value.ID}, ${Math.Calc[${Priority} + ${Ship.ModuleList_TargetModules.ActiveCountOn[${entity_iterator.Value.ID}]}*100]}]
							}
							if ${entity_iterator.Value.BeingTargeted}
							{
								This.LockedAndLockingTargetListBuffer:Insert[${entity_iterator.Value.ID}]
							}
						}
					}
					else
					{
						break
					}
				}
				while ${entity_iterator:Next(exists)}
			}

			if ${entity_iterator.Value(exists)} && ${ListOutOfRange}
			{
				do
				{
					if ${entity_iterator.Value.IsLockedTarget} || ${entity_iterator.Value.BeingTargeted}
					{
						TargetList_DeadDelay:Set[${entity_iterator.Value.ID}, ${Math.Calc[${LavishScript.RunningTime} + 5000]}]
					}
					excludeByNameSubstring:Set[FALSE]
					ExcludeTargetNameIncludeString:GetIterator[excludeNamePartIterator]
					if ${excludeNamePartIterator:First(exists)}
					{
						do
						{
							if ${entity_iterator.Value.Name.Find[${excludeNamePartIterator.Value}]}
							{
								excludeByNameSubstring:Set[TRUE]
								break
							}
						}
						while ${excludeNamePartIterator:Next(exists)}
					}
					if !${ExcludeTargetID.Contains[${entity_iterator.Value.ID}]} && \
						!${entity_iterator.Value.Name.Find["CONCORD"]} && \
						!${excludeByNameSubstring} && \
						!${AlreadyInList.Contains[${entity_iterator.Value.ID}]}
					{
						This.TargetListBufferOOR:Insert[${entity_iterator.Value.ID}]
						AlreadyInList:Add[${entity_iterator.Value.ID}]
						TargetLockPrioritysBuffer:Set[${entity_iterator.Value.ID}, ${Math.Calc[${Priority}-1000]}]
						if ${entity_iterator.Value.IsLockedTarget}
						{
							This.LockedTargetListBufferOOR:Insert[${entity_iterator.Value.ID}]
							This.LockedAndLockingTargetListBufferOOR:Insert[${entity_iterator.Value.ID}]
							TargetLockPrioritysBuffer:Set[${entity_iterator.Value.ID}, ${Math.Calc[(${Priority}-1000) + ${Ship.ModuleList_TargetModules.ActiveCountOn[${entity_iterator.Value.ID}]}*100]}]
						}
						if ${entity_iterator.Value.BeingTargeted}
						{
							This.LockedAndLockingTargetListBufferOOR:Insert[${entity_iterator.Value.ID}]
						}
					}
				}
				while ${entity_iterator:Next(exists)}
			}
		}
		return TRUE
	}


	member:bool PopulateList()
	{
		This.TargetList:Clear
		This.LockedTargetList:Clear
		This.LockedAndLockingTargetList:Clear
		This.TargetLockPrioritys:Clear

		This:DeepCopyEntityIndex["This.TargetListBuffer", "This.TargetList"]

		This:DeepCopyEntityIndex["This.TargetListBufferOOR", "This.TargetList"]

		This:DeepCopyEntityIndex["This.LockedTargetListBuffer", "This.LockedTargetList"]

		This:DeepCopyEntityIndex["This.LockedTargetListBufferOOR", "This.LockedTargetList"]

		This:DeepCopyEntityIndex["This.LockedAndLockingTargetListBuffer", "This.LockedAndLockingTargetList"]

		This:DeepCopyEntityIndex["This.LockedAndLockingTargetListBufferOOR", "This.LockedAndLockingTargetList"]

		This:DeepCopyCollection["This.TargetLockPrioritysBuffer", "This.TargetLockPrioritys"]

		This.TargetListBuffer:Clear
		This.TargetListBufferOOR:Clear
		This.LockedTargetListBuffer:Clear
		This.LockedTargetListBufferOOR:Clear
		This.LockedAndLockingTargetListBuffer:Clear
		This.LockedAndLockingTargetListBufferOOR:Clear
		This.TargetLockPrioritysBuffer:Clear
		AlreadyInList:Clear
		return TRUE
	}

	member:bool ManageLocks()
	{
		variable bool NeedLock = FALSE
		variable int TopLocks = 0
		variable bool IsTopLocked = FALSE
		variable iterator LockIterator
		variable int LowestPriority = 999999999
		variable int64 LowestLock = -1
		if !${Client.InSpace} || ${Me.ToEntity.Mode} == MOVE_WARPING
		{
			return TRUE
		}
		variable iterator EntityIterator
		variable int MaxTarget = ${MyShip.MaxLockedTargets}
		if ${Me.MaxLockedTargets} < ${MyShip.MaxLockedTargets}
		{
			MaxTarget:Set[${Me.MaxLockedTargets}]
		}
		This.LockedTargetList:GetIterator[EntityIterator]
		if ${EntityIterator:First(exists)}
		{
			do
			{
				if !${OwnedTargets.Contains[${EntityIterator.Value.ID}]}
				{
					LockedAndLockingTargets:Add[${EntityIterator.Value.ID}]
					OwnedTargets:Add[${EntityIterator.Value.ID}]
				}
			}
			while ${EntityIterator:Next(exists)}
		}

		This.LockedAndLockingTargets:GetIterator[EntityIterator]
		if ${EntityIterator:First(exists)}
		{
			do
			{
				if !${Entity[${EntityIterator.Value}](exists)} || (!${Entity[${EntityIterator.Value}].IsLockedTarget} && !${Entity[${EntityIterator.Value}].BeingTargeted})
				{
					OwnedTargets:Remove[${EntityIterator.Value}]
					LockedAndLockingTargets:Remove[${EntityIterator.Value}]
				}
			}
			while ${EntityIterator:Next(exists)}
		}

		This.TargetList:GetIterator[EntityIterator]



		if ${LockTop}
		{
			if ${EntityIterator:First(exists)}
			{
				do
				{
					if ${EntityIterator.Value.ID(exists)}
					{
						IsTopLocked:Set[FALSE]
						if ${EntityIterator.Value.IsLockedTarget} || ${EntityIterator.Value.BeingTargeted}
						{
							TopLocks:Inc
							IsTopLocked:Set[TRUE]
						}
						if !${IsTopLocked}
						{
							break
						}
					}
				}
				while ${EntityIterator:Next(exists)}
			}
			if ${TopLocks} < ${MinLockCount}
			{
				NeedLock:Set[TRUE]
			}
		}
		else
		{
			if ${LockedAndLockingTargets.Used} < ${MinLockCount}
			{
				NeedLock:Set[TRUE]
			}
		}

		if ${NeedLock} && ${LockTop} && ${LockedAndLockingTargets.Used} >= ${MinLockCount}
		{
			LockedTargetList:GetIterator[LockIterator]
			if ${LockIterator:First(exists)}
			{
				do
				{
					if ${TargetLockPrioritys.Element[${LockIterator.Value}]} < ${LowestPriority}
					{
						LowestLock:Set[${LockIterator.Value.ID}]
						LowestPriority:Set[${TargetLockPrioritys.Element[${LockIterator.Value}]}]
					}
				}
				while ${LockIterator:Next(exists)}
			}
		}

		if ${NeedLock}
		{
			if ${EntityIterator:First(exists)}
			{
				do
				{
					if ${EntityIterator.Value.ID(exists)}
					{
						if ${LockTop} && !${EntityIterator.Value.IsLockedTarget} && !${EntityIterator.Value.BeingTargeted} && ${LockedAndLockingTargets.Used} >= ${MinLockCount} && ${TargetLockPrioritys.Element[${EntityIterator.Value.ID}]} > ${LowestPriority} && ${EntityIterator.Value.Distance} < ${MyShip.MaxTargetRange} && (${EntityIterator.Value.Distance} < ${MaxRange} || ${LockOutOfRange}) && ${TargetList_DeadDelay.Element[${EntityIterator.Value.ID}]} < ${LavishScript.RunningTime}
						{
							Entity[${LowestLock}]:UnlockTarget
							This:InsertState["ManageLocks"]
							This:InsertState["Idle", 1000]
							return TRUE
						}
						if !${EntityIterator.Value.ID.Equal[${MyShip.ID}]} \	/* Don't lock oneself */
							&& !${EntityIterator.Value.IsLockedTarget} && !${EntityIterator.Value.BeingTargeted} && ${LockedAndLockingTargets.Used} < ${MinLockCount} && ${MaxTarget} > (${Me.TargetCount} + ${Me.TargetingCount}) && ${EntityIterator.Value.Distance} < ${MyShip.MaxTargetRange} && (${EntityIterator.Value.Distance} < ${MaxRange} || ${LockOutOfRange}) && ${TargetList_DeadDelay.Element[${EntityIterator.Value.ID}]} < ${LavishScript.RunningTime}
						{
							EntityIterator.Value:LockTarget
							LockedAndLockingTargets:Add[${EntityIterator.Value.ID}]
							OwnedTargets:Add[${EntityIterator.Value.ID}]
							This:QueueState["Idle", ${Math.Rand[200]}]
							return TRUE
						}
					}
				}
				while ${EntityIterator:Next(exists)}
			}
		}
		return TRUE
	}


	method LockTarget(int64 Target, int Priority)
	{
		variable iterator LockIterator
		variable int LowestPriority = 9999999
		variable int64 LowestLock
		if ${LockedAndLockingTargets.Used} >= ${MinLockCount}
		{
			TargetLockPrioritys:GetIterator[LockIterator]
			if ${LockIterator:First(exists)}
			{
				do
				{
					if ${LockIterator.Value} < ${LowestPriority}
					{
						LowestLock:Set[${LockIterator.Key}]
						LowestPriority:Set[${LockIterator.Value}]
					}
				}
				while ${LockIterator:Next(exists)}
			}
			if ${LowestPriority} < ${Priority}
			{
				Entity[${LowestLock}]:UnlockTarget
				return FALSE
			}
		}
		This:InsertState[LockNewTarget, 250, ${ID}]
	}

	member:bool LockNewTarget(int64 ID)
	{
		if ${Entity[${ID}](exists)}
		{
			Entity[${ID}]:LockTarget
		}
		return TRUE
	}


	method DeepCopyEntityIndex(string From, string To)
	{
		variable iterator EntityIterator
		${From}:GetIterator[EntityIterator]
		if ${EntityIterator:First(exists)}
		{
			do
			{
				${To}:Insert[${EntityIterator.Value.ID}]
			}
			while ${EntityIterator:Next(exists)}
		}
	}

	method DeepCopyCollection(string From, string To)
	{
		variable iterator ColIterator
		${From}:GetIterator[ColIterator]
		if ${ColIterator:First(exists)}
		{
			do
			{
				${To}:Set[${ColIterator.Key}, ${ColIterator.Value}]
			}
			while ${ColIterator:Next(exists)}
		}
	}

}