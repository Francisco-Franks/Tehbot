objectdef obj_Configuration_DroneData
{
	variable string SetName = "Drone Data"

	variable filepath CONFIG_PATH = "${Script.CurrentDirectory}/data"
	variable string CONFIG_FILE = "DroneData.xml"
	variable settingsetref BaseRef

	method Initialize()
	{
		LavishSettings[DroneData]:Clear
		LavishSettings:AddSet[DroneData]

		if ${CONFIG_PATH.FileExists["${CONFIG_FILE}"]}
		{
			LavishSettings[DroneData]:Import["${CONFIG_PATH}/${CONFIG_FILE}"]
		}
		BaseRef:Set[${LavishSettings[DroneData].FindSet[DroneTypes]}]

		Logger:Log["Configuration", " ${This.SetName}: Initialized", "-g"]
	}

	method Shutdown()
	{
		LavishSettings[DroneData]:Clear
	}

	member:string DroneType(int TypeID)
	{
		variable iterator DroneTypes
		BaseRef:GetSetIterator[DroneTypes]
		if ${DroneTypes:First(exists)}
		{
			do
			{
				if ${DroneTypes.Value.FindSetting[${TypeID}](exists)}
				{
					return ${DroneTypes.Key}
				}
			}
			while ${DroneTypes:Next(exists)}
		}
	}

	member:float GetVolume(string DroneType)
	{
		variable iterator DroneTypes
		variable iterator Drones
		BaseRef:GetSetIterator[DroneTypes]
		if ${DroneTypes:First(exists)}
		{
			do
			{
				DroneTypes.Value:GetSettingIterator[Drones]
				if ${Drones:First(exists)}
				{
					do
					{
						if ${Drones.Value.FindAttribute[Type].String.Equal[${DroneType}]}
						{
							return ${Drones.Value.FindAttribute[Volume].Float}
						}
					}
					while ${Drones:Next(exists)}
				}
			}
			while ${DroneTypes:Next(exists)}
		}
		return -1
	}

	member:string SearchSimilarDroneFromRace(string DroneType, int RaceID)
	{
		variable iterator DroneTypes
		variable iterator Drones
		variable settingsetref TargetDroneType
		BaseRef:GetSetIterator[DroneTypes]
		if ${DroneTypes:First(exists)}
		{
			do
			{
				DroneTypes.Value:GetSettingIterator[Drones]
				if ${Drones:First(exists)}
				{
					do
					{
						if ${Drones.Value.FindAttribute[Type].String.Equal[${DroneType}]}
						{
							TargetDroneType:Set[${DroneTypes.Value}]
							break
						}
					}
					while ${Drones:Next(exists)}

					if ${TargetDroneType}
					{
						break
					}
				}
			}
			while ${DroneTypes:Next(exists)}
		}

		variable string affix = ""
		variable bool isNavy = FALSE
		if ${DroneType.Find["'Integrated'"]}
		{
			affix:Set["'Integrated'"]
		}
		elseif ${DroneType.Find["'Augmented'"]}
		{
			affix:Set["'Augmented'"]
		}
		elseif ${DroneType.Find["Navy"]} || ${DroneType.Find["Fleet"]}
		{
			isNavy:Set[TRUE]
		}
		elseif ${DroneType.Find[" II"]}
		{
			affix:Set[" II"]
		}
		elseif ${DroneType.Find[" I"]}
		{
			affix:Set[" I"]
		}

		TargetDroneType:GetSettingIterator[Drones]
		do
		{
			if ${Drones.Value.FindAttribute[Race].Int} == ${RaceID} && \
			   ((!${affix.Equal[""]} && \
			     ${Drones.Value.FindAttribute[Type].String.Find[${affix}]}) || \
			    ((${isNavy} && \
			     (${Drones.Value.FindAttribute[Type].String.Find[Navy]} || \
			      ${Drones.Value.FindAttribute[Type].String.Find[Fleet]})))
			{
				return ${Drones.Value.FindAttribute[Type].String}
			}
		}
		while ${Drones:Next(exists)}

		return NULL
	}

	member:int FindType(string TypeName)
	{
		variable iterator DroneTypeIDs
		BaseRef.FindSet[${TypeName}]:GetSettingIterator[DroneTypeIDs]
		if ${DroneTypeIDs:First(exists)}
		{
			do
			{
				if ${Drones.InactiveDroneCount[TypeID = ${DroneTypeIDs.Key}]} > 0
				{
					return ${DroneTypeIDs.Key}
				}
			}
			while ${DroneTypeIDs:Next(exists)}
		}
		return -1
	}
}


objectdef obj_Drones inherits obj_StateQueue
{
	variable obj_Configuration_DroneData Data
	variable set ActiveTypes
	variable set ReturningDrones
	variable collection:queue TypeQueues
	variable int64 ActivateTargetCache
	; No other methods to get HP of drones in bay.
	variable collection:int DroneHealth

	method Initialize()
	{
		This[parent]:Initialize
		PulseFrequency:Set[2000]
	}

	method RecallAll()
	{
		This:LogInfo["Recalling Drones"]
		EVE:Execute[CmdDronesReturnToBay]
		DronesOut:Set[FALSE]
	}

	method RefreshActiveTypes()
	{
		ActiveTypes:Clear
		variable index:activedrone ActiveDrones
		Me:GetActiveDrones[ActiveDrones]
		ActiveDrones:GetIterator[DroneIterator]
		if ${DroneIterator:First(exists)}
		{
			do
			{
				ActiveTypes:Add[${DroneIterator.Value.TypeID}]
			}
			while ${DroneIterator:Next(exists)}
		}
	}

	method Deploy(string TypeQuery, int Count=-1)
	{
		if ${Count} <= 0
			return

		variable index:item DronesInBay
		variable set DronesToLaunchSet
		variable index:int64 DronesToLaunchList
		variable iterator DroneIterator
		variable int Launched = 0

		DronesToLaunchSet:Clear
		MyShip:GetDrones[DronesInBay]
		DronesInBay:RemoveByQuery[${LavishScript.CreateQuery[${TypeQuery}]}, FALSE]
		DronesInBay:Collapse
		if ${DronesInBay.Used} <= ${Count}
		{
			; echo Launch all
			DronesInBay:GetIterator[DroneIterator]
			if ${DroneIterator:First(exists)}
			{
				do
				{
					ActiveTypes:Add[${DroneIterator.Value.TypeID}]
					DronesToLaunchList:Insert[${DroneIterator.Value.ID}]
					if ${ReturningDrones.Contains[${DroneIterator.Value.ID}]}
						ReturningDrones:Remove[${DroneIterator.Value.ID}]
				}
				while ${DroneIterator:Next(exists)}
			}
		}
		else
		{
			; echo Launch top ${Count} healthest
			while ${Launched} < ${Count}
			{
				DronesInBay:GetIterator[DroneIterator]
				variable int healthestDroneHealth = 0
				healthestDroneHealth:Set[0]
				variable int64 healthestDroneID = 0
				variable int healthestDroneTypeID = 0
				if ${DroneIterator:First(exists)}
				{
					do
					{
						; Treat drone with unknown health as full health
						variable int currentDroneHealth = 300
						currentDroneHealth:Set[300]
						if ${DroneHealth.Element[${DroneIterator.Value.ID}](exists)}
						{
							currentDroneHealth:Set[${DroneHealth.Element[${DroneIterator.Value.ID}]}]
						}

						if !${DronesToLaunchSet.Contains[${DroneIterator.Value.ID}]} && ${currentDroneHealth} > ${healthestDroneHealth}
						{
							healthestDroneID:Set[${DroneIterator.Value.ID}]
							healthestDroneHealth:Set[${currentDroneHealth}]
							healthestDroneTypeID:Set[${DroneIterator.Value.TypeID}]
						}
					}
					while ${DroneIterator:Next(exists)}
					if ${ReturningDrones.Contains[${healthestDroneID}]}
						ReturningDrones:Remove[${healthestDroneID}]
					ActiveTypes:Add[${healthestDroneTypeID}]
					DronesToLaunchSet:Add[${healthestDroneID}]
					DronesToLaunchList:Insert[${healthestDroneID}]
					Launched:Inc
				}
			}
		}

		if ${DronesToLaunchList.Used}
			EVE:LaunchDrones[DronesToLaunchList]
	}

	method Recall(string TypeQuery, int Count=-1)
	{
		variable index:activedrone ActiveDrones
		variable index:int64 DronesToRecall
		variable iterator DroneIterator
		variable int Selected = 0
		Me:GetActiveDrones[ActiveDrones]
		ActiveDrones:RemoveByQuery[${LavishScript.CreateQuery[${TypeQuery}]}, FALSE]
		ActiveDrones:Collapse
		ActiveDrones:GetIterator[DroneIterator]
		if ${DroneIterator:First(exists)}
		{
			do
			{
				if ${Selected} >= ${Count} && ${Count} > 0
				{
					break
				}
				DronesToRecall:Insert[${DroneIterator.Value.ID}]
				ReturningDrones:Add[${DroneIterator.Value.ID}]
				Selected:Inc
			}
			while ${DroneIterator:Next(exists)}
		}
		EVE:DronesReturnToDroneBay[DronesToRecall]
	}

	member:int GetTargeting(int64 TargetID)
	{
		variable index:activedrone ActiveDrones
		variable iterator DroneIterator
		variable int Targeting = 0
		Me:GetActiveDrones[ActiveDrones]
		ActiveDrones:GetIterator[DroneIterator]
		if ${DroneIterator:First(exists)}
		{
			do
			{
				if ${DroneIterator.Value.Target.ID.Equal[${TargetID}]}
				{
					Targeting:Inc
				}
			}
			while ${DroneIterator:Next(exists)}
		}
		return ${Targeting}
	}

	method Engage(string TypeQuery, int64 TargetID, bool Force=FALSE, int Count = -1)
	{
		ActivateTargetCache:Set[${TargetID}]
		if ${This.IsIdle}
			This:QueueState["SwitchActiveTarget", -1, "${TypeQuery}, ${Force}, ${Count}"]
	}

	member:int InactiveDroneCount(string TypeQuery)
	{
		variable index:item DronesInBay
		MyShip:GetDrones[DronesInBay]
		DronesInBay:RemoveByQuery[${LavishScript.CreateQuery[${TypeQuery}]}, FALSE]
		DronesInBay:Collapse[]
		return ${DronesInBay.Used}
	}

	member:int ActiveDroneCount(string TypeQuery)
	{
		variable index:activedrone ActiveDrones
		Me:GetActiveDrones[ActiveDrones]
		ActiveDrones:RemoveByQuery[${LavishScript.CreateQuery[${TypeQuery}]}, FALSE]
		ActiveDrones:Collapse[]
		return ${ActiveDrones.Used}
	}

	member:bool IdleDrone()
	{
		variable index:activedrone ActiveDrones
		Me:GetActiveDrones[ActiveDrones]
		ActiveDrones:RemoveByQuery[${LavishScript.CreateQuery["State = 0"]}, FALSE]
		ActiveDrones:Collapse[]
		return ${ActiveDrones.Used}
	}

	member:bool SwitchActiveTarget(string TypeQuery, bool Force = FALSE, int Count = -1)
	{
		if !${Entity[${ActivateTargetCache}].IsLockedTarget}
		{
			return TRUE
		}

		if ${Entity[${ActivateTargetCache}].IsActiveTarget}
		{
			This:QueueState["EngageActiveTarget", -1, "${TypeQuery}, ${Force}, ${Count}"]
			return TRUE
		}
		else
		{
			; echo switching
			Entity[${ActivateTargetCache}]:MakeActiveTarget
			return FALSE
		}
	}

	member:bool EngageActiveTarget(string TypeQuery, bool Force = FALSE, int Count = -1)
	{
		 ;echo engaging
		variable index:activedrone ActiveDrones
		variable index:int64 DronesToEngage
		variable iterator DroneIterator
		variable int Selected = 0

		Me:GetActiveDrones[ActiveDrones]
		 ;echo ${ActiveDrones.Used} ${TypeQuery}
		ActiveDrones:RemoveByQuery[${LavishScript.CreateQuery[${TypeQuery}]}, FALSE]
		ActiveDrones:Collapse
		ActiveDrones:GetIterator[DroneIterator]
		 ;echo ${ActiveDrones.Used}
		if ${DroneIterator:First(exists)}
		{
			do
			{
				if ${Selected} >= ${Count} && ${Count} > 0
				{
					break
				}

				if !${ReturningDrones.Contains[${DroneIterator.Value.ID}]} && !${DroneIterator.Value.Target.ID.Equal[${ActivateTargetCache}]}
				{
					; echo ${DroneIterator.Value.ID} engaging ${Entity[${ActivateTargetCache}].Name}
					DronesToEngage:Insert[${DroneIterator.Value.ID}]
					Selected:Inc
				}
			}
			while ${DroneIterator:Next(exists)}
		}
		if ${Selected} > 0
		{
			EVE:DronesEngageMyTarget[DronesToEngage]
		}
		return TRUE
	}

	member:int DronesInSpace()
	{
		variable index:activedrone ActiveDrones
		Me:GetActiveDrones[ActiveDrones]
		return ${ActiveDrones.Used}
	}

	member:int DronesInBay()
	{
		variable index:item Drones
		MyShip:GetDrones[Drones]
		return ${Drones.Used}
	}

	; Not working
	method RefreshDroneHealthCache()
	{
		variable index:activedrone ActiveDrones
		variable iterator DroneIterator
		Me:GetActiveDrones[ActiveDrones]
		ActiveDrones:GetIterator[DroneIterator]
		if ${DroneIterator:First(exists)}
		{
			do
			{
				variable float currentDroneHealth = ${Math.Calc[${DroneIterator.Value.ToEntity.ShieldPct.Int} + ${DroneIterator.Value.ToEntity.ArmorPct.Int} + ${DroneIterator.Value.ToEntity.StructurePct.Int}]}
				Drones.DroneHealth:Set[${DroneIterator.Value.ID}, ${currentDroneHealth.Int}]
			}
			while ${DroneIterator:Next(exists)}
		}
	}

}