#include <sourcemod>
#include <sdktools>

public Plugin:myinfo =
{
	name = "[D3S] Smoke Teleport",
	author = "Mateusz Dukat d3s",
	description = "Teleport by smoke grenades.",
	version = "1.0",
	url = ""
}

public smoke_id[100];
public int smoke_i;
public int smokes_on_map;
public Float:smoke_f_Pos[100][3];
public bool debug_mode;

public OnPluginStart()
{
	debug_mode = false;
	smoke_i = 0;
	smokes_on_map = 0;
	for(int i = 0; i<100; i++){
		smoke_id[i] = 0;
		smoke_f_Pos[i][0] = 0.0;
		smoke_f_Pos[i][1] = 0.0;
		smoke_f_Pos[i][2] = 0.0;
	}
		
	
	HookEvent("smokegrenade_detonate", addsmoketp);
	HookEvent("smokegrenade_expired", rmsmoketp);
	HookEvent("round_start", clearsmoketp);
	HookEvent("grenade_thrown", smokegiver);
	
	RegConsoleCmd("tpme", smoketp); // bind `tpme` to any button, to teleport in smoke
	
	//HookEvent("player_ping", pingtp);
	
}

public Action smoketp(int client, int args)
{
	// TODO: BALANCE ME: Add cooldown before next teleport for each player

	new Float:f_Pos[3];
	GetClientAbsOrigin(client, f_Pos);
	
	if(debug_mode){
		PrintToChatAll("Trying to teleport at %f %f %f", f_Pos[0], f_Pos[1], f_Pos[2]);
	}
	
	// Find in which smoke player is
	for(int i = 0; i<smoke_i; i++){
		// TODO: Define smoke box as structure, then in function check if player is in box
		if(f_Pos[0] > smoke_f_Pos[i][0]-50 && f_Pos[0] < smoke_f_Pos[i][0]+50){ //			X	// This basically checks if
			if(f_Pos[1] > smoke_f_Pos[i][1]-50 && f_Pos[1] < smoke_f_Pos[i][1]+50){ //		Y	// player is in a little box in smoke
				if(f_Pos[2] > smoke_f_Pos[i][2]-30 && f_Pos[2] < smoke_f_Pos[i][2]+30){ //	Z
					
					// TODO: Build function set for stack operations
					// Find bottom of smoke_id stack
					int nmin = 0;
					for(int x = 0; x<smoke_i; x++){
						if(smoke_id[x] != 0){
							nmin = x;
							break;
						}
					}
					
					// If there are more than 1 smokes, get random and teleport
					if(smokes_on_map > 1){
						int irand = GetRandomInt(nmin, smoke_i-1);
						while(irand == i){
							// Thats a really bad while loop, don't do it.
							irand = GetRandomInt(nmin, smoke_i-1);
						}
						TeleportEntity(client, smoke_f_Pos[irand], NULL_VECTOR, NULL_VECTOR);
						if(debug_mode){
							PrintToChatAll("Teleported");
						}
					}else{
						if(debug_mode){
							// TODO: Change output to client console, add plugin tag before message
							PrintToChatAll("Nowhere to teleport");
						}
					}
					break;
				}
			}
		}
	}
}

// BALANCE ME: Define how much smoke grenades player get, right now it's infinity
public smokegiver(Handle:event, const String:name[], bool:dontBroadcast)
{
	new userid = GetEventInt(event, "userid");
	
	char weapon[50]
	GetEventString(event, "weapon", weapon, 50);
	
	if(strcmp(weapon, "weapon_smokegrenade")){ // If thrown weapon is smoke, give next one
		new client = GetClientOfUserId(userid);
		GivePlayerItem(client, "weapon_smokegrenade");
	}
}

public clearsmoketp(Handle:event, const String:name[], bool:dontBroadcast)
{
	for(int i = 0; i<smoke_i; i++){
		smoke_id[i] = 0;
		smoke_f_Pos[i][0] = 0.0;
		smoke_f_Pos[i][1] = 0.0;
		smoke_f_Pos[i][2] = 0.0;
	}
	smoke_i = 0;
	smokes_on_map = 0;

	if(debug_mode){
		PrintToChatAll("Round clear smoke");
	}
}

// TODO: Fix syntax of whole code (function names, function definition, overall look)
public addsmoketp(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Some data
	smokes_on_map += 1;
	
	// Grab entityid
	new entityid = GetEventInt(event, "entityid");
	smoke_id[smoke_i] = entityid;
	
	// Grab entity position
	new Float:f_Pos[3];
	f_Pos[0] = GetEventFloat(event, "x");
	f_Pos[1] = GetEventFloat(event, "y");
	f_Pos[2] = GetEventFloat(event, "z");
	smoke_f_Pos[smoke_i] = f_Pos;
	smoke_i += 1;
	
	// DEBUG
	if(debug_mode){
		PrintToChatAll("Smoke boom");
		PrintToChatAll("%f %f %f", f_Pos[0], f_Pos[1], f_Pos[2]);
		PrintToChatAll("All Smokes:");
		for(int i = 0; i<smoke_i; i++)
		{
			if(smoke_id[i] != 0){
				PrintToChatAll("%f %f %f", smoke_f_Pos[i][0], smoke_f_Pos[i][1], smoke_f_Pos[i][2]);
			}
		}
	}
}

public rmsmoketp(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Some data
	smokes_on_map -= 1;
	
	new entityid = GetEventInt(event, "entityid");
	int this_i = 0;
	for(int i = 0; i<smoke_i; i++){ // Find smoke
		if(smoke_id[i] == entityid){
			this_i = i;
			break;
		}
	}
	
	if(debug_mode){
		PrintToChatAll("Cleared smoke %f %f %f", smoke_f_Pos[this_i][0], smoke_f_Pos[this_i][1], smoke_f_Pos[this_i][2]);
	}
	
	smoke_id[this_i] = 0;
	smoke_f_Pos[this_i][0] = 0.0;
	smoke_f_Pos[this_i][1] = 0.0;
	smoke_f_Pos[this_i][2] = 0.0;
}

// TODO Make pingtp as an option, defined by command perhaps (same with whole smoketp)?
/*
public pingtp(Handle:event, const String:name[], bool:dontBroadcast)
{
	new userid = GetEventInt(event, "userid");
	new client = GetClientOfUserId(userid);

	new Float:f_Pos[3];
	//new entityid = GetEventInt(event, "entityid");
	f_Pos[0] = GetEventFloat(event, "x");
	f_Pos[1] = GetEventFloat(event, "y");
	f_Pos[2] = GetEventFloat(event, "z");

	TeleportEntity(client, f_Pos, NULL_VECTOR, NULL_VECTOR);
	//RemoveEdict(entityid);
}
*/
