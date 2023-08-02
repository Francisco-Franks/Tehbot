; Entity category
#define CATEGORYID_CELESTIAL																					2
#define CATEGORYID_STATION 																						3
#define CATEGORYID_SHIP    																						6
#define CATEGORYID_ENTITY																						11
#define CATEGORYID_ORE     																						25
#define CATEGORYID_STRUCTURE                                                                                    65
#define CATEGORYID_STARBASE		                                                                                23

; Module type id
#define TYPE_MEGA_PULSE_LASER                                                                                   3057
#define TYPE_TORPEDO_LAUNCHER                                                                                   2420
#define TYPE_800MM_REPEATING_CANNON                                                                             2929
#define TYPE_XLARGE_ANCILLARY_SHIELD_BOOSTER                                                                    32780
#define TYPE_RAPID_HEAVY_LAUNCHER																				33450
#define TYPE_VORTON_WEAPON																						54753
#define TYPE_VORTON_WEAPON_MED																					54748

; Module group id
#define GROUPID_CONTROL_TOWER                                                                                   365
#define GROUP_FREQUENCY_MINING_LASER 																			483
#define GROUP_ENERGYWEAPON 																						53
#define GROUP_HYBRIDWEAPON 																						74
#define GROUP_PRECURSORWEAPON																					1986
#define GROUP_PROJECTILEWEAPON 																					55
#define GROUP_VORTONWEAPON																						4060
#define GROUP_MISSILEGUIDANCECOMPUTER																			1396
#define GROUP_MISSILELAUNCHER 																					56
#define GROUP_MISSILELAUNCHERASSAULT 																			511
#define GROUP_MISSILELAUNCHERBOMB 																				862
#define GROUP_MISSILELAUNCHERCITADEL 																			524
#define GROUP_MISSILELAUNCHERCRUISE 																			506
#define GROUP_MISSILELAUNCHERDEFENDER 																			512
#define GROUP_MISSILELAUNCHERHEAVY 																				510
#define GROUP_MISSILELAUNCHERHEAVYASSAULT 																		771
#define GROUP_MISSILELAUNCHERROCKET 																			507
#define GROUP_MISSILELAUNCHERTORPEDO																			508
#define GROUP_MISSILELAUNCHERSTANDARD 																			509
#define GROUP_MISSILELAUNCHERRAPIDHEAVY																			1245
#define GROUP_SHIELD_TRANSPORTER         																		41
#define GROUP_ARMOR_PROJECTOR	         																		325
#define GROUP_MUTADAPTIVE_PROJECTOR	         																	2018
#define GROUP_CLOAKING_DEVICE		 																			330
#define GROUP_GANGLINK 																							316

#define GROUP_STRIPMINER 																						464
#define GROUP_MININGLASER 																						54
#define GROUP_GASCLOUDHARVESTER																					4138
#define GROUP_GASCLOUDSCOOP																						737
#define GROUP_COMPRESSOR																						4174


#define GROUP_ECCM 																								202
#define GROUP_DRONECONTROLUNIT																					407
#define GROUP_AFTERBURNER 																						46
#define GROUP_SHIELD_BOOSTER 																					40
#define GROUP_ANCILLARY_SHIELD_BOOSTER 																			1156
#define GROUP_SHIELD_HARDENER 																					77
#define GROUP_ARMOR_REPAIRERS 																					62
#define GROUP_ARMOR_HARDENERS 																					328
#define GROUP_ARMOR_RESISTANCE_SHIFT_HARDENER																	1150
#define GROUP_DAMAGE_CONTROL 																					60
#define GROUP_SALVAGER 																							1122
#define GROUP_TRACTOR_BEAM 																						650
#define GROUP_SCRAMBLER																							52
#define GROUP_SURVEYSCANNER																						49
#define GROUP_COMMANDBURST																						1770
#define GROUP_STASIS_GRAPPLER 																					1672
#define GROUP_STASIS_WEB 																						65
#define GROUP_SENSORBOOSTER 																					212
#define GROUP_TARGETPAINTER 																					379
#define GROUP_ENERGY_VAMPIRE 																					68
#define GROUP_ENERGY_TRANSFER																					67
#define GROUP_TRACKINGCOMPUTER 																					213
#define GROUP_AUTOMATED_TARGETING_SYSTEM																		96

#define GROUP_SIEGEMODULE 																						515
#define GROUP_CONCORDDRONE 																						301
#define GROUP_CONVOY 																							297
#define GROUP_CONVOYDRONE 																						298
#define GROUP_LARGECOLLIDABLEOBJECT 																			226
#define GROUP_LARGECOLLIDABLESHIP 																				784
#define GROUP_LARGECOLLIDABLESTRUCTURE 																			319
#define GROUP_SPAWNCONTAINER 																					306
#define GROUP_DEADSPACEOVERSEERSSTRUCTURE 																		494
#define GROUP_PRESSURESOLO 																						952
#define GROUP_ANCIENTSHIPSTRUCTURE 																				1207
#define GROUP_WRECK 																							186
#define GROUP_CARGOCONTAINER 																					12
#define GROUP_WARPGATE 																							366
#define GROUP_SUN 																								6
#define GROUP_SCOUT_DRONE 																						100
#define GROUP_COMBAT_DRONE 																						549
#define GROUP_SALVAGE_DRONE																						1159

#define GROUP_ENERGYNEUT																						71
#define GROUP_WEAPONDISRUPTOR																					291
#define GROUP_ECM																								201
#define GROUP_RSD																								208

; Drone race
#define DRONE_RACE_CALDARI 																						1
#define DRONE_RACE_MINMATAR 																					2
#define DRONE_RACE_AMARR 																						4
#define DRONE_RACE_GALLENTE 																					8

; Log level
#define LOG_DEBUG                                                                                               1
#define LOG_INFO                                                                                                2
#define LOG_CRITICAL                                                                                            3

; Module target
; Don't need to distinguish these 2 in our case.
#define TARGET_NA																			                    0
#define TARGET_ANY																			                    0

; Module instruction
#define INSTRUCTION_NONE																	                    0
#define INSTRUCTION_ACTIVATE_ON																                    1
#define INSTRUCTION_DEACTIVATE																                    2
#define INSTRUCTION_RELOAD_AMMO																                    3
#define INSTRUCTION_ACTIVATE_FOR												                    	        4
#define INSTRUCTION_ACTIVATE_ONCE														                    	5

; Ship mode
#define MOVE_ALIGNED                                                                                            0
#define MOVE_APPROACHING                                                                                        1
#define MOVE_STOPPED                                                                                            2
#define MOVE_WARPING                                                                                            3
#define MOVE_ORBITING                                                                                           4

; Do not set this to 1 unless you have downloaded and installed ISXIM extension from http://updates.isxgames.com/isxim/ISXIM.exe
; Allows logging to IRC and Jabber, etc
#define USE_ISXIM 1