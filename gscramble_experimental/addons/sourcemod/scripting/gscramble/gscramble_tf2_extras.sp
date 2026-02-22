/************************************************************************
*************************************************************************
gScramble tf2 extras (Modernized)
Description:
	Snippets that make working with tf2 more fun! 
*************************************************************************
*************************************************************************/

// Accurately pulls the round timer length by finding the earliest active timer entity
stock void GetRoundTimerInformation(bool delay = false)
{
	if (delay)
	{
		CreateTimer(0.5, TimerRoundTimer);
		return;
	}

	int round_timer = -1;
	float best_end_time = 1000000000000.0;
	float timer_end_time;
	bool found_valid_timer = false;
	bool timer_is_disabled = true;
	bool timer_is_paused = true;

	while ((round_timer = FindEntityByClassname(round_timer, "team_round_timer")) != -1) {
		timer_is_paused = view_as<bool>(GetEntProp(round_timer, Prop_Send, "m_bTimerPaused"));
		timer_is_disabled = view_as<bool>(GetEntProp(round_timer, Prop_Send, "m_bIsDisabled"));
		
		timer_end_time = GetEntPropFloat(round_timer, Prop_Send, "m_flTimerEndTime");
		
		if (!timer_is_paused && !timer_is_disabled && (timer_end_time <= best_end_time || !found_valid_timer)) {
			best_end_time = timer_end_time;
			found_valid_timer = true;
		}
	}
	
	if (found_valid_timer) {
		g_fRoundEndTime = best_end_time;
		g_bRoundIsTimed = true;
	} else {
		g_RoundState = roundNormal; // 'normal' renamed to 'roundNormal' to avoid shadowing warnings
		g_bRoundIsTimed = false;
	}
}

public Action TimerRoundTimer(Handle timer)
{
	GetRoundTimerInformation();
	return Plugin_Handled;
}

stock bool TF2_HasBuilding(int client)
{
	if (TF2_ClientBuilding(client, "obj_*"))
	{
		return true;
	}
	return false;
}

// Scans all map objects to see if our client's handle is the listed m_hBuilder
stock bool TF2_ClientBuilding(int client, const char[] building)
{
	int iEnt = -1;
	while ((iEnt = FindEntityByClassname(iEnt, building)) != -1)
	{
		if (GetEntDataEnt2(iEnt, FindSendPropInfo("CBaseObject", "m_hBuilder")) == client)
		{
			return true;
		}
	}
	return false;
}

// Manipulates the round timer entity natively via AcceptEntityInput
stock void TF2_ResetSetup()
{
	g_iTimerEnt = FindEntityByClassname(-1, "team_round_timer");
	int setupDuration = GetTime() - g_iRoundStartTime; 
	SetVariantInt(setupDuration);
	AcceptEntityInput(g_iTimerEnt, "AddTime");
	g_iRoundStartTime = GetTime();
}

stock bool TF2_IsClientUberCharged(int client)
{
	if (!IsPlayerAlive(client))
	{
		return false;
	}
	
	TFClassType class = TF2_GetPlayerClass(client);
	if (class == TFClass_Medic)
	{			
		int iIdx = GetPlayerWeaponSlot(client, 1);
		if (iIdx > 0)
		{
			char sClass[33];
			GetEntityNetClass(iIdx, sClass, sizeof(sClass));
			if (StrEqual(sClass, "CWeaponMedigun", true))
			{
				float chargeLevel = GetEntPropFloat(iIdx, Prop_Send, "m_flChargeLevel");
				if (chargeLevel >= cvar_BalanceChargeLevel.FloatValue)
				{
					return true;
				}
			}
		}
	}
	return false;
}

// Checks multiple TF2 conditions to account for stock ubers, kritz, and vaccinator resists
stock bool TF2_IsClientUbered(int client)
{
	if (TF2_IsPlayerInCondition(client, TFCond_Ubercharged) 
		|| TF2_IsPlayerInCondition(client, TFCond_Kritzkrieged) 
		|| TF2_IsPlayerInCondition(client, TFCond_UberchargeFading)
		|| TF2_IsPlayerInCondition(client, TFCond_UberBulletResist)
		|| TF2_IsPlayerInCondition(client, TFCond_UberBlastResist)
		|| TF2_IsPlayerInCondition(client, TFCond_UberFireResist))
	{
		return true;
	}
	return false;
}

stock int TF2_GetPlayerDominations(int client)
{
	int offset = FindSendPropInfo("CTFPlayerResource", "m_iActiveDominations");
	int ent = FindEntityByClassname(-1, "tf_player_manager");
	if (ent != -1)
	{
		return GetEntData(ent, (offset + client*4), 4);
	}
	return 0;
}

stock int TF2_GetTeamDominations(int team)
{
	int dominations;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == team)
		{
			dominations += TF2_GetPlayerDominations(i);
		}
	}
	return dominations;
}

// Returns true if the client is the ONLY medic on their team (used for vital protections)
stock bool TF2_IsClientOnlyMedic(int client)
{
	if (view_as<TFClassType>(TF2_GetPlayerClass(client)) != TFClass_Medic)
	{
		return false;
	}
	
	int clientTeam = GetClientTeam(client);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (i != client && IsClientInGame(i) && GetClientTeam(i) == clientTeam && view_as<TFClassType>(TF2_GetPlayerClass(i)) == TFClass_Medic)
		{
			return false;
		}
	}
	return true;
}

// Modernized UserMsg hook. Uses BfRead object to read the internal string.
public Action UserMessageHook_Class(UserMsg msg_id, BfRead bf, const int[] players, int playersNum, bool reliable, bool init) 
{	
	char strMessage[50];
	bf.ReadString(strMessage, sizeof(strMessage), true);
	if (StrContains(strMessage, "#TF_TeamsSwitched", true) != -1)
	{
		SwapPreferences();
		int oldRed = g_aTeams[iRedWins], oldBlu = g_aTeams[iBluWins];
		
		g_aTeams[iRedWins] = oldBlu;
		g_aTeams[iBluWins] = oldRed;
		
		g_iTeamIds[0] == TEAM_RED ? (g_iTeamIds[0] = TEAM_BLUE) :  (g_iTeamIds[0] = TEAM_RED);
		g_iTeamIds[1] == TEAM_RED ? (g_iTeamIds[1] = TEAM_BLUE) :  (g_iTeamIds[1] = TEAM_RED);
	}
	
	return Plugin_Continue;
}

stock void TF2_RemoveRagdolls()
{
	int iEnt = -1;
	while ((iEnt = FindEntityByClassname(iEnt, "tf_ragdoll")) != -1)
	{
		AcceptEntityInput(iEnt, "Kill");
	}
}

// Compares the two cart watcher entities on payload maps to find the furthest progression
stock float GetCartProgress()
{
	int iEnt = -1;
	float fTotalProgress_1, fTotalProgress_2;
	bool bFoundCart = false;
		
	while((iEnt = FindEntityByClassname(iEnt, "team_train_watcher")) != -1 )
	{
		if (IsValidEntity(iEnt))
		{
			if (GetEntProp(iEnt, Prop_Data, "m_bDisabled"))
				continue;
			if (!bFoundCart)
			{
				fTotalProgress_1 = GetEntPropFloat(iEnt, Prop_Send, "m_flTotalProgress");
				bFoundCart = true;
				continue;
			}
			fTotalProgress_2 = GetEntPropFloat(iEnt, Prop_Send, "m_flTotalProgress");
			break;
		}
	}
	if (fTotalProgress_1 > fTotalProgress_2)
		return fTotalProgress_1;
	return fTotalProgress_2;
}

stock bool DoesClientHaveIntel(int client)
{
	int iEnt = -1;
	while ((iEnt = FindEntityByClassname(iEnt, "item_teamflag")) != -1) 
	{
		if (IsValidEntity(iEnt))
		{
			if (GetEntPropEnt(iEnt, Prop_Data, "m_hMoveParent") == client)
				return true;
		}
	}
	return false;
}