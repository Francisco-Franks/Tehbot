objectdef obj_Configuration_WatchDog inherits obj_Configuration_Base
{
	method Initialize()
	{
		This[parent]:Initialize["WatchDog"]
	}

	method Set_Default_Values()
	{
		ConfigManager.ConfigRoot:AddSet[${This.SetName}]
	}

}

objectdef obj_WatchDog inherits obj_StateQueue
{
	
	method Initialize()
	{
		This[parent]:Initialize
		This.NonGameTiedPulse:Set[TRUE]
		This.PulseFrequency:Set[5000]
		DynamicAddMiniMode("WatchDog", "WatchDog")

		This.LogLevelBar:Set[${CommonConfig.LogLevelBar}]
	}

	method Start()
	{
		This:QueueState["WatchDog", 5000]
	}

	method Stop()
	{
		This:Clear
	}
	; Alright so this will be our main loop. This minimode's existence is to gather statistics from our DBs, and update variables
	; These variables will be displayed in some form or another in the UI for this minimode, it will be designed to opened and left opened
	; So that you can see your stats at a glance. Reading the DBs shouldnt be blocking so there should be no issues there. This Minimode
	; Will NOT do any writes to the DB of any kind.
	; Furthermore, this mode will, when I stop being lazy, handle getting a bot "unstuck" if it detects a lack of progress over some arbitrary amount of time.
	; For reference we have Mission.CharacterSQLDB , Mission.SharedSQLDB as our DBs we will be looking at.
	; The tables we care about in Mission.CharacterSQLDB will be MissionLogCombat, MissionLogCourier, and NPCInfo
	; The tables we care about in Mission.SharedSQLDB will be WatchDogMonitoring, MissioneerStats, and SalvageBMTable.
	; From MissionLogCombat and MissionLogCourier we will be able to identify what kinds of missions we get and how often. We will also be able to identify average mission duration.
	; From NPCInfo we can see what kinds of enemies we face, how many enemies are in each mission, etc.
	; From WatchDogMonitoring we will only really just be doing a baseline check to see if a client has stopped updating.
	; From MissioneerStats we will be able to see the average bounties per run, per day, and overall. Same for LP rewards
	; From SalvageBMTable we can determine if the salvagers have disconnected/died/gotten stuck. Also if we are outpacing the salvagers so we can do some adjusting.
	; For the moment this minimode is going to be mostly about displaying information. Later on I will work on the WatchDog functionality.
	member:bool WatchDog()
	{

		
	}
}



