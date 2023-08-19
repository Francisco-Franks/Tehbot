#include core/Defines.iss
#include core/Macros.iss

; Keep and updated
#include core/obj_Tehbot.iss
; Keep and updated
#include core/obj_Configuration.iss
; Updated, possibly still need to remove independent pulse if it's not used
#include core/obj_StateQueue.iss
; Keep and updated
#include core/obj_TehbotUI.iss
#include core/obj_Logger.iss
#include core/obj_MissionParser.iss
; Need to implement menu/config item for accepting fleet invites from corp members
; Update undock warp bookmark search to use aligned once it's moved to production out of dev version
; Probably need to restore undock minimode check, think undocks always happen right now
; Probably get rid of the Inventory member
#include core/obj_Client.iss
; Probably can be further cleaned up.  Remove unneeded move types, remove fleet warps, remove ignore gate stuff
; Probably need to rethink Approach and Orbit behaviors.  Make both separate modules, or let behaviors manage them on their own?
#include core/obj_Move.iss
; clear
#include core/obj_Module.iss
; clear
#include core/obj_ModuleList.iss
; May work, need to verify querys work with strings instead of IDs
#include core/obj_Ship.iss
#include core/obj_Ship2.iss
#include core/obj_CombatComputer.iss
; Might remove altogether
#include core/obj_Cargo.iss
; May need more work, quickly removed IPC and profiling
#include core/obj_TargetList.iss
; clear
#include core/obj_Drones.iss
; clear
#include core/obj_Login.iss
; clear
#include core/obj_Dynamic.iss
; want to try and remove
;#include core/obj_Busy.iss
#include core/obj_CombatComputerTaskHelper.iss
#include core/obj_TargetingDatabase.iss
#include core/obj_DimensionalNavigation.iss

; clear
#include core/obj_NPCData.iss
#include core/obj_FactionData.iss
#include core/obj_PrioritizedTargets.iss
#include core/obj_Utility.iss

#include behavior/MiniMode.iss
#include behavior/Salvager.iss
#include behavior/Mission.iss
;#include behavior/Mission2.iss
#include behavior/Abyssal.iss
#include behavior/Mining.iss
#include behavior/CombatAnoms.iss
#include behavior/Observer.iss

#include minimode/Automate.iss
#include minimode/AutoModule.iss
#include minimode/AutoThrust.iss
#include minimode/DroneControl.iss
#include minimode/InstaWarp.iss
#include minimode/FightOrFlight.iss
#include minimode/RemoteRepManagement.iss
#include minimode/TargetManager.iss
#include minimode/MissionTargetManager.iss
#include minimode/Salvage.iss
#include minimode/UndockWarp.iss
;#include minimode/PanicButtons.iss
#include minimode/MinerForeman.iss
#include minimode/MinerWorker.iss
#include minimode/LocalCheck.iss
#include minimode/LavishNavTest.iss
#include minimode/ChatRelay.iss
#include minimode/ISXSQLiteTest.iss
#include minimode/PilotInfoHelper.iss
#include minimode/WatchDog.iss

function atexit()
{

}

function main(string Character="")
{
	declarevariable EVEExtension obj_EVEExtension script
	EVEExtension.Character:Set[${Character}]
	call EVEExtension.Initialize
	ext -require isxSQLite

	echo "${Time} Tehbot: Starting"
	Turbo 1000

	declarevariable ConfigManager obj_Configuration_Manager script
	declarevariable CommonConfig obj_Configuration_Common script
	declarevariable UI obj_TehbotUI script
	declarevariable Logger obj_Logger script
	declarevariable Tehbot obj_Tehbot script
	UI:Reload

	declarevariable NPCData obj_NPCData script
	declarevariable FactionData obj_FactionData script
	declarevariable PrioritizedTargets obj_PrioritizedTargets script
	declarevariable Utility obj_Utility script
	declarevariable TehbotLogin obj_Login script
	declarevariable Dynamic obj_Dynamic script

	declarevariable MiniMode obj_MiniMode script
	declarevariable Salvager obj_Salvager script
	declarevariable MissionParser obj_MissionParser script
	declarevariable Mission obj_Mission script
	;declarevariable Mission2 obj_Mission2 script
	declarevariable Abyssal obj_Abyssal script
	declarevariable Mining obj_Mining script
	declarevariable CombatAnoms obj_CombatAnoms script
	declarevariable Observer obj_Observer script

	declarevariable Automate obj_Automate script
	declarevariable AutoModule obj_AutoModule script
	declarevariable AutoThrust obj_AutoThrust script
	declarevariable InstaWarp obj_InstaWarp script
	declarevariable FightOrFlight obj_FightOrFlight script
	declarevariable RemoteRepManagement obj_RemoteRepManagement script
	declarevariable TargetManager	obj_TargetManager script
	declarevariable MissionTargetManager	obj_MissionTargetManager script
	declarevariable CCTH1 obj_CombatComputerTaskHelper script
	declarevariable UndockWarp obj_UndockWarp script
	declarevariable Salvage obj_Salvage script
	declarevariable DroneControl obj_DroneControl script
	;declarevariable PanicButtons obj_PanicButtons script
	declarevariable MinerForeman obj_MinerForeman script
	declarevariable MinerWorker obj_MinerWorker script
	declarevariable LocalCheck obj_LocalCheck script
	declarevariable LavishNavTest obj_LavishNavTest script
	declarevariable ChatRelay obj_ChatRelay script
	declarevariable PilotInfoHelper obj_PilotInfoHelper script
	declarevariable WatchDog obj_WatchDog script
	if ${ISXSQLite.IsReady}
	{
		declarevariable ISXSQLiteTest obj_ISXSQLiteTest script
	}

	Dynamic:PopulateBehaviors
	Dynamic:PopulateMiniModes

	while TRUE
	{
		if ${Me(exists)} && ${MyShip(exists)} && (${Me.InSpace} || ${Me.InStation})
		{
			break
		}
		wait 10
	}
	CommonConfig:SetCharID[${Me.CharID}]

	declarevariable Client obj_Client script
	declarevariable Move obj_Move script
	declarevariable Ship obj_Ship script
	declarevariable Ship2 obj_Ship2 script
	declarevariable CombatComputer obj_CombatComputer script
	declarevariable DimensionalNavigation obj_DimensionalNavigation script
	;declarevariable TargetingDatabase obj_TargetingDatabase script
	declarevariable Cargo obj_Cargo script
	declarevariable RefineData obj_Configuration_RefineData script
	declarevariable Drones obj_Drones script
	
	;Just what everyone likes, global variables. Need these for information sharing between Offense Manager, Position Manager, and Target Manager
	declarevariable CurrentOffenseRange float global
	declarevariable CurrentRepRange float global
	declarevariable CurrentOffenseTarget int64 global
	declarevariable CurrentRepTarget int64 global
	declarevariable AllowSiegeModule bool global
	declarevariable CurrentOffenseTargetExpectedShots int64 global
	
	;More global variables, this is for keeping track of when we last attempted (successfully or not) to use a drug
	declarevariable BluePillTime int64 global
	declarevariable HardshellTime int64 global
	declarevariable ExileTime int64 global
	
	;More global variable(s), lets see if this fixes our orbit problems
	declarevariable orbitTarget = 0 int64 global
	;Another two global variables, these are supposed to indicate when the target choice is FINAL for both TargetManager and DroneControl | Let us see what happens.
	declarevariable finalizedTM bool global
	declarevariable finalizedDC bool global
	;Global variable for localcheck minimode
	declarevariable FriendlyLocal bool global
	;Global bool for Inhibiting the operation of TargetManager (so we don't shoot weird things, or other circumstances)
	declarevariable TargetManagerInhibited bool global
	;Global string for AmmoOverride, that is to say, to force a specific ammo.
	declarevariable AmmoOverride string global
	;Global string to manage the failings of ModuleList
	declarevariable WeaponSwitch string global

	;declarevariable CCTHTM taskmanager global ${LMAC.NewTaskManager["CCTHTM"]}

	Logger:Log["Tehbot", "Module initialization complete", "y"]

	if ${CommonConfig.AutoStart}
	{
		Tehbot:Resume
	}
	else
	{
		Logger:Log["Tehbot", "Paused", "r"]
	}


	while TRUE
	{
		wait 10
	}
}
