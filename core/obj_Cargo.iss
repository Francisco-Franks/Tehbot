objectdef obj_CargoAction
{
	variable string Bookmark
	variable string LocationType
	variable string LocationSubtype
	variable string Container
	variable string Action
	variable string QueryString
	variable int Quantity
	variable string Source

	method Initialize(string arg_Bookmark, string arg_Action, string arg_LocationType, string arg_LocationSubtype, string arg_Container, string arg_QueryString, int arg_Quantity, string arg_Source)
	{
		Bookmark:Set["${arg_Bookmark.Escape}"]
		LocationType:Set[${arg_LocationType}]
		LocationSubtype:Set[${arg_LocationSubtype}]
		Container:Set[${arg_Container}]
		Action:Set[${arg_Action}]
		QueryString:Set["${arg_QueryString.Escape}"]
		Quantity:Set[${arg_Quantity}]
		Source:Set[${arg_Source}]
	}

	method Set(string arg_Bookmark, string arg_Action, string arg_LocationType, string arg_LocationSubtype, string arg_Container, string arg_QueryString, int arg_Quantity, string arg_Source)
	{
		Bookmark:Set["${arg_Bookmark.Escape}"]
		LocationType:Set[${arg_LocationType}]
		LocationSubtype:Set[${arg_LocationSubtype}]
		Container:Set[${arg_Container}]
		Action:Set[${arg_Action}]
		QueryString:Set["${arg_QueryString.Escape}"]
		Quantity:Set[${arg_Quantity}]
		Source:Set[${arg_Source}]
	}

	method Clear()
	{
		Bookmark:Set[""]
		LocationType:Set[""]
		LocationSubtype:Set[""]
		Container:Set[""]
		Action:Set[""]
		QueryString:Set[""]
		Quantity:Set[0]
		Source:Set[""]
	}
}

objectdef obj_Cargo inherits obj_StateQueue
{
	variable bool Processing=FALSE
	variable queue:obj_CargoAction CargoQueue
	variable obj_CargoAction BuildAction
	variable index:item CargoList

	variable bool Active=FALSE

	method Initialize()
	{
		This[parent]:Initialize
		This.PulseFrequency:Set[500]
	}

	method ActivateSource(string location, int64 ID=-1)
	{
		switch ${location}
		{
			case Ship
				if ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipCargo](exists)}
				{
					EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipCargo]:MakeActive
				}
				break
			case ShipCorpHangar
				if ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipFleetHangar](exists)}
				{
					EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipFleetHangar]:MakeActive
				}
				break
			case OreHold
				if ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipGeneralMiningHold](exists)}
				{
					EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipGeneralMiningHold]:MakeActive
				}
				break
			case Corporation Hangar
				if ${EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationCorpHangar](exists)}
				{
					EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationCorpHangars]:MakeActive
				}
				if ${EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StructureCorpHangar](exists)}
				{
					EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StructureCorpHangars]:MakeActive
				}
				break
			case Personal Hangar
				if ${EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems](exists)}
				{
					EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:MakeActive
				}
				if ${EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StructureItemHangar](exists)}
				{
					EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StructureItemHangar]:MakeActive
					Client:Wait[4000]
				}
				Me.Station:GetHangarItems[CargoList]
				break
		}
	}

	method PopulateCargoList(string location, int64 ID=-1, string Folder="")
	{
		switch ${location}
		{
			case Ship
				MyShip:GetCargo[CargoList]
				break
			case ShipCorpHangar
				MyShip:GetFleetHangarCargo[CargoList]
				break
			case OreHold
				MyShip:GetOreHoldCargo[CargoList]
				break
			case CONTAINERCORPORATEHANGAR
				Entity[${ID}]:GetCorpHangarsCargo[CargoList]
				break
			case Corporation Hangar
				Me.Station:GetCorpHangarItems[CargoList]
				break
			case Personal Hangar
				Me.Station:GetHangarItems[CargoList]
				break
			case Container
				Entity[${ID}]:GetCargo[CargoList]
		}


		switch ${Folder}
		{
			case Corporation Folder 1
				This:Filter["SlotID = 4"]
				break
			case Corporation Folder 2
				This:Filter["SlotID = 116"]
				break
			case Corporation Folder 3
				This:Filter["SlotID = 117"]
				break
			case Corporation Folder 4
				This:Filter["SlotID = 118"]
				break
			case Corporation Folder 5
				This:Filter["SlotID = 119"]
				break
			case Corporation Folder 6
				This:Filter["SlotID = 120"]
				break
			case Corporation Folder 7
				This:Filter["SlotID = 121"]
				break
		}

	}

	method Filter(string Filter)
	{
		if ${CargoList.Used}
		{
			CargoList:RemoveByQuery[${LavishScript.CreateQuery["${Filter}"]}, FALSE]
			CargoList:Collapse
		}
	}

	method DontPopCan()
	{
		variable iterator Cargo
		variable index:int64 TransferIndex
		variable float Volume = 0
		variable bool EarlyBreak=FALSE
		variable int64 LastItem = -1

		CargoList:GetIterator[Cargo]
		if ${Cargo:First(exists)}
		{
			do
			{
				if !${LastItem.Equal[-1]}
				{
					TransferIndex:Insert[${LastItem}]
				}
				if (${Cargo.Value.Quantity} * ${Cargo.Value.Volume}) < ${Math.Calc[${MyShip.CargoCapacity} - ${MyShip.UsedCargoCapacity} - ${Volume}]}
				{
					LastItem:Set[${Cargo.Value.ID}]
					Volume:Inc[${Math.Calc[${Cargo.Value.Quantity} * ${Cargo.Value.Volume}]}]
				}
				else
				{
					EarlyBreak:Set[TRUE]
					if ${Cargo.Value.Volume} != 0
					{
						Cargo.Value:MoveTo[MyShip, CargoHold, ${Math.Calc[(${MyShip.CargoCapacity} - ${MyShip.UsedCargoCapacity} - ${Volume}) / ${Cargo.Value.Volume} - 1]}]
					}
					break
				}
			}
			while ${Cargo:Next(exists)}
			Cargo:Last
			if !${EarlyBreak}
			{
				if ${Cargo.Value.Quantity} > 1
				{
					Cargo.Value:MoveTo[MyShip, CargoHold, ${Math.Calc[${Cargo.Value.Quantity} - 1]}]
				}
			}
			if ${TransferIndex.Used} > 0
			{
				EVE:MoveItemsTo[TransferIndex, MyShip, CargoHold]
			}
		}
	}

	method MoveCargoList(string location, string folder="", int64 ID=-1, int Quantity=0)
	{
		variable string TransferFolder
		variable float Volume

		if ${location.Equal[OreHold]}
		{
			This:Filter[CategoryID==CATEGORYID_ORE]
		}

		if ${CargoList.Used} == 1
		{
			variable item CargoItem=${CargoList[1].ID}
			if ${CargoItem.Volume} == 0
			{
				return
			}

			if ${Quantity} > 0
			{
				Volume:Set[${CargoItem.Volume} * ${Quantity}]
			}
			else
			{
				Volume:Set[${CargoItem.Volume} * ${CargoItem.Quantity}]
				Quantity:Set[${CargoItem.Quantity}]
			}

			if ${folder.Length}
			{
				TransferFolder:Set[\, ${folder.Escape}]
			}

			switch ${location}
			{
				case SHIP
					if ${Volume} < ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipCargo].Capacity} - ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipCargo].UsedCapacity}
					{
						CargoItem:MoveTo[MyShip, CargoHold, ${Quantity}]
					}
					else
					{
						CargoItem:MoveTo[MyShip, CargoHold, ${Math.Calc[(${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipCargo].Capacity} - ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipCargo].UsedCapacity}) / ${CargoItem.Volume}].Int}]
					}
					break
				case Container
					if ${ID} != -1
					{
						if ${Volume} < ${EVEWindow[Inventory].ChildWindow[${ID}].Capacity} - ${EVEWindow[Inventory].ChildWindow[${ID}].UsedCapacity}
						{
							CargoItem:MoveTo[${ID}, None, ${Quantity}${TransferFolder}]
						}
						else
						{
							CargoItem:MoveTo[${ID}, None, ${Math.Calc[(${EVEWindow[Inventory].ChildWindow[${ID}].Capacity} - ${EVEWindow[Inventory].ChildWindow[${ID}].UsedCapacity}) / ${CargoItem.Volume}].Int}${TransferFolder}]
						}
					}
					break
				case Fleet Hangar
					if ${ID} == -1
					{
						if ${Volume} < ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipFleetHangar].Capacity} - ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipFleetHangar].UsedCapacity}
						{
							CargoItem:MoveTo[MyShip, FleetHangar, ${Quantity}]
						}
						else
						{
							CargoItem:MoveTo[MyShip, FleetHangar, ${Math.Calc[(${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipFleetHangar].Capacity} - ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipFleetHangar].UsedCapacity}) / ${CargoItem.Volume}].Int}]
						}
					}
					else
					{
						if ${Volume} < ${EVEWindow[Inventory].ChildWindow[${ID}].Capacity} - ${EVEWindow[Inventory].ChildWindow[${ID}].UsedCapacity}
						{
							CargoItem:MoveTo[${ID}, FleetHangar, ${Quantity}${TransferFolder}]
						}
						else
						{
							CargoItem:MoveTo[${ID}, FleetHangar, ${Math.Calc[(${EVEWindow[Inventory].ChildWindow[${ID}].Capacity} - ${EVEWindow[Inventory].ChildWindow[${ID}].UsedCapacity}) / ${CargoItem.Volume}].Int}${TransferFolder}]
						}
					}
					break
				case Jetcan
					if ${Volume} < ${EVEWindow[Inventory].ChildWindow[${ID}].Capacity} - ${EVEWindow[Inventory].ChildWindow[${ID}].UsedCapacity}
					{
						CargoItem:MoveTo[${ID}, None, ${Quantity}${TransferFolder}]
					}
					else
					{
						CargoItem:MoveTo[${ID}, None, ${Math.Calc[(${EVEWindow[Inventory].ChildWindow[${ID}].Capacity} - ${EVEWindow[Inventory].ChildWindow[${ID}].UsedCapacity}) / ${CargoItem.Volume}].Int}]
					}
					break
				case OreHold
					if ${Volume} < ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipGeneralMiningHold].Capacity} - ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipGeneralMiningHold].UsedCapacity}
					{
						CargoItem:MoveTo[MyShip, OreHold, ${Quantity}]
					}
					else
					{
						CargoItem:MoveTo[MyShip, OreHold, ${Math.Calc[(${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipGeneralMiningHold].Capacity} - ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipGeneralMiningHold].UsedCapacity}) / ${CargoItem.Volume}].Int}]
					}
					break
				case Personal Hangar
					CargoItem:MoveTo[MyStationHangar, Hangar, ${Quantity}]
					break
				case Corporation Hangar
					CargoItem:MoveTo[MyStationCorporateHangar, StationCorporateHangar, ${Quantity}${TransferFolder}]
					break
			}
		}
		else
		{
			variable iterator Cargo
			Volume:Set[0]
			variable index:int64 TransferIndex
			CargoList:GetIterator[Cargo]

			if ${Cargo:First(exists)}
				do
				{
					TransferIndex:Insert[${Cargo.Value.ID}]
				}
				while ${Cargo:Next(exists)}

			if ${folder.Length}
			{
				TransferFolder:Set[\, ${folder.Escape}]
			}

			switch ${location}
			{
				case SHIP
					TransferIndex:Clear
					if ${Cargo:First(exists)}
						do
						{
							if ${Cargo.Value.Quantity} * ${Cargo.Value.Volume} < ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipCargo].Capacity} - ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipCargo].UsedCapacity} - ${Volume}
							{
								TransferIndex:Insert[${Cargo.Value.ID}]
								Volume:Inc[${Math.Calc[${Cargo.Value.Quantity} * ${Cargo.Value.Volume}]}]
							}
							elseif ${Cargo.Value.Volume} != 0
							{
								if ${Math.Calc[(${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipCargo].Capacity} - ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipCargo].UsedCapacity} - ${Volume}) / ${Cargo.Value.Volume}].Int}
								{
									Cargo.Value:MoveTo[MyShip, CargoHold, ${Math.Calc[(${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipCargo].Capacity} - ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipCargo].UsedCapacity} - ${Volume}) / ${Cargo.Value.Volume}].Int}]
									break
								}
							}
						}
						while ${Cargo:Next(exists)}
					EVE:MoveItemsTo[TransferIndex, MyShip, CargoHold]
					break
				case Container
					TransferIndex:Clear
					if ${ID} != -1
					{
						if ${Cargo:First(exists)}
							do
							{
								if ${Cargo.Value.Quantity} * ${Cargo.Value.Volume} < ${EVEWindow[Inventory].ChildWindow[${ID}].Capacity} - ${EVEWindow[Inventory].ChildWindow[${ID}].UsedCapacity} - ${Volume}
								{
									TransferIndex:Insert[${Cargo.Value.ID}]
									Volume:Inc[${Cargo.Value.Quantity} * ${Cargo.Value.Volume}]
								}
								elseif ${Cargo.Value.Volume} != 0
								{
									if ${Math.Calc[(${EVEWindow[Inventory].ChildWindow[${ID}].Capacity} - ${EVEWindow[Inventory].ChildWindow[${ID}].UsedCapacity} - ${Volume}) / ${Cargo.Value.Volume}].Int}
									{
										Cargo.Value:MoveTo[${ID}, None, ${Math.Calc[(${EVEWindow[Inventory].ChildWindow[${ID}].Capacity} - ${EVEWindow[Inventory].ChildWindow[${ID}].UsedCapacity} - ${Volume}) / ${Cargo.Value.Volume}].Int}${TransferFolder}]
										break
									}
								}
							}
							while ${Cargo:Next(exists)}
						EVE:MoveItemsTo[TransferIndex, ${ID}, None${TransferFolder}]
					}
					break
				case Fleet Hangar
					TransferIndex:Clear
					if ${ID} == -1
					{
						if ${Cargo:First(exists)}
							do
							{
								if ${Cargo.Value.Quantity} * ${Cargo.Value.Volume} < ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipFleetHangar].Capacity} - ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipFleetHangar].UsedCapacity} - ${Volume}
								{
									TransferIndex:Insert[${Cargo.Value.ID}]
									Volume:Inc[${Cargo.Value.Quantity} * ${Cargo.Value.Volume}]
								}
								elseif ${Cargo.Value.Volume} != 0
								{
									if ${Math.Calc[(${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipFleetHangar].Capacity} - ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipFleetHangar].UsedCapacity} - ${Volume}) / ${Cargo.Value.Volume}].Int}
									{
										Cargo.Value:MoveTo[MyShip, FleetHangar, ${Math.Calc[(${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipFleetHangar].Capacity} - ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipFleetHangar].UsedCapacity} - ${Volume}) / ${Cargo.Value.Volume}].Int}]
										break
									}
								}
							}
							while ${Cargo:Next(exists)}
						EVE:MoveItemsTo[TransferIndex, MyShip, FleetHangar]
					}
					else
					{
						if ${Cargo:First(exists)}
							do
							{
								if ${Cargo.Value.Quantity} * ${Cargo.Value.Volume} < ${EVEWindow[Inventory].ChildWindow[${ID}].Capacity} - ${EVEWindow[Inventory].ChildWindow[${ID}].UsedCapacity} - ${Volume}
								{
									TransferIndex:Insert[${Cargo.Value.ID}]
									Volume:Inc[${Cargo.Value.Quantity} * ${Cargo.Value.Volume}]
								}
								elseif ${Cargo.Value.Volume} != 0
								{
									if ${Math.Calc[(${EVEWindow[Inventory].ChildWindow[${ID}].Capacity} - ${EVEWindow[Inventory].ChildWindow[${ID}].UsedCapacity} - ${Volume}) / ${Cargo.Value.Volume}].Int}
									{
										Cargo.Value:MoveTo[${ID}, FleetHangar, ${Math.Calc[(${EVEWindow[Inventory].ChildWindow[${ID}].Capacity} - ${EVEWindow[Inventory].ChildWindow[${ID}].UsedCapacity} - ${Volume}) / ${Cargo.Value.Volume}].Int}]
										break
									}
								}
							}
							while ${Cargo:Next(exists)}
						EVE:MoveItemsTo[TransferIndex, ${ID}, FleetHangar]
					}
					break
				case Jetcan
					TransferIndex:Clear
					if ${Cargo:First(exists)}
						do
						{
							if ${Cargo.Value.Quantity} * ${Cargo.Value.Volume} < ${EVEWindow[Inventory].ChildWindow[${ID}].Capacity} - ${EVEWindow[Inventory].ChildWindow[${ID}].UsedCapacity} - ${Volume}
							{
								TransferIndex:Insert[${Cargo.Value.ID}]
								Volume:Inc[${Cargo.Value.Quantity} * ${Cargo.Value.Volume}]
							}
							elseif ${Cargo.Value.Volume} != 0
							{
								if ${Math.Calc[(${EVEWindow[Inventory].ChildWindow[${ID}].Capacity} - ${EVEWindow[Inventory].ChildWindow[${ID}].UsedCapacity} - ${Volume}) / ${Cargo.Value.Volume}].Int}
								{
									Cargo.Value:MoveTo[${ID}, None, ${Math.Calc[(${EVEWindow[Inventory].ChildWindow[${ID}].Capacity} - ${EVEWindow[Inventory].ChildWindow[${ID}].UsedCapacity} - ${Volume}) / ${Cargo.Value.Volume}].Int}]
									break
								}
							}
						}
						while ${Cargo:Next(exists)}
					EVE:MoveItemsTo[TransferIndex, ${ID}]
					break
				case OreHold
					TransferIndex:Clear
					if ${Cargo:First(exists)}
						do
						{
							if ${Cargo.Value.Quantity} * ${Cargo.Value.Volume} < ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipGeneralMiningHold].Capacity} - ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipGeneralMiningHold].UsedCapacity} - ${Volume}
							{
								TransferIndex:Insert[${Cargo.Value.ID}]
								Volume:Inc[${Cargo.Value.Quantity} * ${Cargo.Value.Volume}]
							}
							elseif ${Cargo.Value.Volume} != 0
							{
								if ${Math.Calc[(${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipGeneralMiningHold].Capacity} - ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipGeneralMiningHold].UsedCapacity} - ${Volume}) / ${Cargo.Value.Volume}].Int}
								{
									Cargo.Value:MoveTo[MyShip, OreHold, ${Math.Calc[(${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipGeneralMiningHold].Capacity} - ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipGeneralMiningHold].UsedCapacity} - ${Volume}) / ${Cargo.Value.Volume}].Int}]
									break
								}
							}
						}
						while ${Cargo:Next(exists)}
					EVE:MoveItemsTo[TransferIndex, MyShip, OreHold]
					break
				case Personal Hangar
					EVE:MoveItemsTo[TransferIndex, MyStationHangar, Hangar]
					break
				case Corporation Hangar
					EVE:MoveItemsTo[TransferIndex, MyStationCorporateHangar, StationCorporateHangar${TransferFolder}]
					break
			}
		}
	}


	method At(string arg_Bookmark, string arg_LocationType = "Personal Hangar", string arg_LocationSubtype = "", string arg_Container = "")
	{
		This.BuildAction:Clear
		This.BuildAction.Bookmark:Set[${arg_Bookmark}]
		This.BuildAction.LocationType:Set[${arg_LocationType}]
		This.BuildAction.LocationSubtype:Set[${arg_LocationSubtype}]
		This.BuildAction.Container:Set[${arg_Container}]
	}

	method Load(string arg_Query = "", int arg_Quantity = 0, string arg_Source = "Ship")
	{
		if ${This.BuildAction.Bookmark.Length} == 0 || \
			${This.BuildAction.LocationType.Length} == 0
		{
			Logger:Log["obj_Cargo", "Attempted to queue an incomplete Load cargo action", "r"]
			return
		}

		This.CargoQueue:Queue[${This.BuildAction.Bookmark}, Load, ${This.BuildAction.LocationType}, ${This.BuildAction.LocationSubtype}, ${This.BuildAction.Container}, ${arg_Query}, ${arg_Quantity}, ${arg_Source}]
		This.Processing:Set[TRUE]
		if ${This.IsIdle}
		{
			This:QueueState["Process"]
		}
	}
	method Unload(string arg_Query, int arg_Quantity = 0, string arg_Source = "Ship")
	{
		if ${This.BuildAction.Bookmark.Length} == 0 || \
			${This.BuildAction.LocationType.Length} == 0
		{
			Logger:Log["obj_Cargo", "Attempted to queue an incomplete Unload cargo action", "r"]
			return
		}

		This.CargoQueue:Queue[${This.BuildAction.Bookmark}, Unload, ${This.BuildAction.LocationType}, ${This.BuildAction.LocationSubtype}, ${This.BuildAction.Container}, ${arg_Query}, ${arg_Quantity}, ${arg_Source}]
		This.Processing:Set[TRUE]
		if ${This.IsIdle}
		{
			This:QueueState["Process"]
		}
	}
	method Move()
	{
		if ${This.BuildAction.Bookmark.Length} == 0
		{
			Logger:Log["obj_Cargo", "Attempted to queue an incomplete Move cargo action", "r"]
			return
		}

		This.CargoQueue:Queue[${This.BuildAction.Bookmark}, Move, "", "", "", "", 0]
		This.Processing:Set[TRUE]
		if ${This.IsIdle}
		{
			This:QueueState["Process"]
		}
	}




	member:bool Process()
	{
		if ${This.CargoQueue.Used} == 0
		{
			This.Processing:Set[FALSE]
			return TRUE
		}

		DroneControl:Recall
		if ${Busy.IsBusy}
		{
			if ${Busy.BusyModes.Used} == 1 && ${Busy.BusyModes.Contains[Salvage]}
			{
				;Leaving here for possible use
			}
			else
			{
				return FALSE
			}
		}

		if ${EVE.Bookmark[${This.CargoQueue.Peek.Bookmark}](exists)}
		{
			Logger:Log["Cargo", "Processing \ao${This.CargoQueue.Peek.Action}", "g"]
			Logger:Log["Cargo", " Location: \ag${This.CargoQueue.Peek.Bookmark}", "-g"]
		}
		if ${EVE.Station[${This.CargoQueue.Peek.Bookmark}](exists)}
		{
			Logger:Log["Cargo", "Processing \ao${This.CargoQueue.Peek.Action}\ag", "g"]
			Logger:Log["Cargo", " Location: \ag${EVE.Station[${This.CargoQueue.Peek.Bookmark}].Name}", "-g"]
		}

		switch ${This.CargoQueue.Peek.Action}
		{
			case Unload
				Logger:Log["Cargo", " Source: \ag${This.CargoQueue.Peek.Source}", "-g"]
				Logger:Log["Cargo", " Destination: \ag${This.CargoQueue.Peek.LocationType}\a-g - \ao${This.CargoQueue.Peek.LocationSubType}\a-g - \ao${This.CargoQueue.Peek.Container}", "-g"]
				break
			case Load
				Logger:Log["Cargo", " Source: \ag${This.CargoQueue.Peek.LocationType}\a-g - \ao${This.CargoQueue.Peek.LocationSubType}\a-g - \ao${This.CargoQueue.Peek.Container}", "-g"]
				Logger:Log["Cargo", " Destination: \agShip", "-g"]
				break
		}

		if !${Local[${This.CargoQueue.Peek.Container}](exists)}
		{
			if ${EVE.Bookmark[${This.CargoQueue.Peek.Bookmark}].TypeID} == 5 && ${EVE.Bookmark[${This.CargoQueue.Peek.Bookmark}].ItemID} != -1
			{
				Move:System[${EVE.Bookmark[${This.CargoQueue.Peek.Bookmark}].SolarSystemID}]
			}
			else
			{
				Move:Bookmark[${This.CargoQueue.Peek.Bookmark}, TRUE]
			}
		}
		This:QueueState["Traveling"]
		This:QueueState["WarpFleetMember"]
		This:QueueState["Traveling"]
		This:QueueState["Activate", 3000]
		This:QueueState["${This.CargoQueue.Peek.Action}"]
		This:QueueState["Stack", 3000]
		This:QueueState["Dequeue"]
		This:QueueState["Process"]
		return TRUE
	}

	member:bool Traveling()
	{
		if ${Move.Traveling} || ${Me.ToEntity.Mode} == MOVE_WARPING
		{
			return FALSE
		}
		return TRUE
	}

	member:bool WarpFleetMember()
	{
		if ${Local[${This.CargoQueue.Peek.Container}](exists)}
		{
			Move:Fleetmember[${Local[${This.CargoQueue.Peek.Container}].ID}]
		}
		return TRUE
	}

	member:bool Dequeue()
	{
		This.CargoQueue:Dequeue
		return TRUE
	}


	member:bool Activate()
	{
		if !${Client.Inventory}
		{
			return FALSE
		}

		Cargo:ActivateSource[${This.CargoQueue.Peek.Source}]
		return TRUE
	}



	member:bool Stack()
	{
		variable int64 Container

		if !${Client.Inventory}
		{
			return FALSE
		}

		if ${Me.InSpace} && ${This.CargoQueue.Peek.Action.NotEqual[Move]}
		{
			if ${Entity[Name = "${This.CargoQueue.Peek.Container}"](exists)}
			{
				Container:Set[${Entity[Name = "${This.CargoQueue.Peek.Container}"].ID}]
				if ${Entity[${Container}].Distance} > 2500
				{
					Move:Approach[${Container}, 2500]
					return FALSE
				}
				else
				{
					if !${EVEWindow[Inventory].ChildWindow[${Container}](exists)}
					{
						Logger:Log["obj_Cargo", "Opening ${This.CargoQueue.Peek.Container}", "g"]
						Entity[${Container}]:Open
						return FALSE
					}
					if ${EVEWindow[Inventory].ChildWindow[${Container}].UsedCapacity} == -1 || \
						${EVEWindow[Inventory].ChildWindow[${Container}].Capacity} <= 0
					{
						Logger:Log["obj_Cargo", "Container information invalid, activating", "g"]
						EVEWindow[Inventory].ChildWindow[${Container}]:MakeActive
						return FALSE
					}
					if ${This.CargoQueue.Peek.LocationType.Equal[Container]}
					{
						EVE:StackItems[${Container}, CorpHangars, ${This.CargoQueue.Peek.LocationSubtype}]
					}
					if ${This.CargoQueue.Peek.LocationType.Equal[Fleet Hangar]}
					{
						EVE:StackItems[${Container}, FleetHangar]
					}
					return TRUE
				}
			}
			else
			{
				Logger:Log["obj_Cargo", "Cargo action Stack failed - Container not found", "r"]
				return TRUE
			}

		}

		if !${EVEWindow[Inventory].ChildWindow[StationCorpHangar](exists)}
		{
			EVEWindow[Inventory].ChildWindow[StationCorpHangars]:MakeActive
		}
		
		if !${EVEWindow[Inventory].ChildWindow[StructureCorpHangar](exists)}
		{
			EVEWindow[Inventory].ChildWindow[StructureCorpHangars]:MakeActive
		}
		
		variable index:item cargo
		if !${EVEWindow[Inventory].ChildWindow["StationCorpHangar", "Folder7"]:GetItems[cargo](exists)}
		{

			EVEWindow[Inventory].ChildWindow["StationCorpHangar", "Folder7"]:MakeActive
			return FALSE
		}

		switch ${This.CargoQueue.Peek.LocationType}
		{
			case Personal Hangar
				EVE:StackItems[MyStationHangar, Hangar]
				break
			case Corporation Hangar
				EVEWindow[Inventory].ChildWindow["StationCorpHangar", "Folder7"]:StackAll
				break
		}

		return TRUE
	}

	member:bool Unload(bool OpenedCorpHangar=FALSE)
	{
		variable int64 Container

		if !${Client.Inventory}
		{
			return FALSE
		}

		if ${Me.InSpace}
		{
			if ${Entity[Name = "${This.CargoQueue.Peek.Container}"](exists)}
			{
				Container:Set[${Entity[Name = "${This.CargoQueue.Peek.Container}"].ID}]
				if ${Entity[${Container}].Distance} > 2500
				{
					Move:Approach[${Container}, 2500]
					return FALSE
				}
				else
				{
					if !${EVEWindow[Inventory].ChildWindow[${Container}](exists)}
					{
						Logger:Log["obj_Cargo", "Opening ${This.CargoQueue.Peek.Container}", "g"]
						Entity[${Container}]:Open
						return FALSE
					}
					if ${EVEWindow[Inventory].ChildWindow[${Container}].UsedCapacity} == -1 || \
						${EVEWindow[Inventory].ChildWindow[${Container}].Capacity} <= 0
					{
						Logger:Log["obj_Cargo", "Container information invalid, activating", "g"]
						EVEWindow[Inventory].ChildWindow[${Container}]:MakeActive
						return FALSE
					}
					Cargo:PopulateCargoList[${This.CargoQueue.Peek.Source}]
					Cargo:Filter[${This.CargoQueue.Peek.QueryString}]
					Cargo:MoveCargoList[${This.CargoQueue.Peek.LocationType}, ${This.CargoQueue.Peek.LocationSubtype}, ${Container}, ${This.CargoQueue.Peek.Quantity}]
					return TRUE
				}
			}
			else
			{
				Logger:Log["obj_Cargo", "Cargo action Unload failed - Container not found", "r"]
				return TRUE
			}
		}

		if !${EVEWindow[Inventory].ChildWindow[StationCorpHangar](exists)} && !${OpenedCorpHangar}
		{
			EVEWindow[Inventory].ChildWindow[StationCorpHangars]:MakeActive
			This:InsertState["Unload", 2000, TRUE]
			return TRUE
		}

		Cargo:PopulateCargoList[${This.CargoQueue.Peek.Source}]
		Cargo:Filter[${This.CargoQueue.Peek.QueryString}]
		Cargo:MoveCargoList[${This.CargoQueue.Peek.LocationType}, ${This.CargoQueue.Peek.LocationSubtype}, ${Container}, ${This.CargoQueue.Peek.Quantity}]
		return TRUE
	}

	member:bool Load(bool OpenedCorpHangar=FALSE)
	{
		variable int64 Container

		if !${Client.Inventory}
		{
			return FALSE
		}

		if ${Me.InSpace}
		{
			if ${Entity[Name = "${This.CargoQueue.Peek.Container}"](exists)}
			{
				Container:Set[${Entity[Name = "${This.CargoQueue.Peek.Container}"].ID}]
				if ${Entity[${Container}].Distance} > 2500
				{
					Move:Approach[${Container}, 2500]
					return FALSE
				}
				else
				{
					if !${EVEWindow[Inventory].ChildWindow[${Container}](exists)}
					{
						Logger:Log["obj_Cargo", "Opening ${This.CargoQueue.Peek.Container}", "g"]
						Entity[${Container}]:Open
						return FALSE
					}
					if ${EVEWindow[Inventory].ChildWindow[${Container}].UsedCapacity} == -1 || \
						${EVEWindow[Inventory].ChildWindow[${Container}].Capacity} <= 0
					{
						Logger:Log["obj_Cargo", "Container information invalid, activating", "g"]
						EVEWindow[Inventory].ChildWindow[${Container}]:MakeActive
						return FALSE
					}
					Cargo:PopulateCargoList[Container, ${Container}, ${This.CargoQueue.Peek.LocationSubtype}]
					Cargo:Filter[${This.CargoQueue.Peek.QueryString}]
					Cargo:MoveCargoList[SHIP, "", -1, ${This.CargoQueue.Peek.Quantity}]
					return TRUE
				}
			}
			else
			{
				Logger:Log["obj_Cargo", "Cargo action Load failed - Container not found", "r"]
				return TRUE
			}
		}

		if !${EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationCorpHangar](exists)} && !${OpenedCorpHangar}
		{
			EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationCorpHangars]:MakeActive
			This:InsertState["Load", 2000, TRUE]
			return TRUE
		}

		Cargo:PopulateCargoList[${This.CargoQueue.Peek.LocationType}, 0, ${This.CargoQueue.Peek.LocationSubtype}]
		Cargo:Filter[${This.CargoQueue.Peek.QueryString}]
		Cargo:MoveCargoList[SHIP, "", -1, ${This.CargoQueue.Peek.Quantity}]
		return TRUE
	}
	member:bool Move()
	{
		return TRUE
	}

}