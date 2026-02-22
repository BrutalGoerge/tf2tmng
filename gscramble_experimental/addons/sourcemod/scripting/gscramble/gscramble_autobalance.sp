/************************************************************************
*************************************************************************
gScramble autobalance logic (Modernized)
Description:
	Autobalance logic for the gscramble addon
*************************************************************************
*************************************************************************/

int g_iImmunityDisabledWarningTime;

stock int GetLargerTeam()
{
	if (GetTeamClientCount(TEAM_RED) > GetTeamClientCount(TEAM_BLUE))
	{
		return TEAM_RED;
	}
	return TEAM_BLUE;
}

stock int GetSmallerTeam()
{
	return GetLargerTeam() == TEAM_RED ? TEAM_BLUE:TEAM_RED;
}

public Action timer_StartBalanceCheck(Handle timer, any client)
{
	if (g_aTeams[bImbalanced] && BalancePlayer(client))
	{
		CheckBalance(true);
	}
	
	return Plugin_Handled;
}

bool BalancePlayer(int client)
{
	if (!TeamsUnbalanced(false))
	{
		return true;
	}
	
	int team, iTime = GetTime();
	bool overrider = false;
	int big = GetLargerTeam();
	team = big == TEAM_RED?TEAM_BLUE:TEAM_RED;
	
	if (cvar_Preference.BoolValue)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && GetClientTeam(i) == big && g_aPlayers[client][iTeamPreference] == team)
			{
				overrider = true;
				client = i;
				break;
			}
		}
	}
	
	if (!overrider)
	{
		if (!IsClientValidBalanceTarget(client))
		{
			return false;	
		}
	}
	else if (IsPlayerAlive(client))
	{
		CreateTimer(0.5, Timer_BalanceSpawn, GetClientUserId(client));
	}
	
	char sName[MAX_NAME_LENGTH + 1], sTeam[32];
	GetClientName(client, sName, 32);
	team == TEAM_RED ? (sTeam = "RED") : (sTeam = "BLU");
	g_bBlockDeath = true;
	ChangeClientTeam(client, team);
	g_bBlockDeath = false;
	g_aPlayers[client][iBalanceTime] = iTime + (cvar_BalanceTime.IntValue * 60);
	
	if (!IsFakeClient(client))
	{
		Event event = CreateEvent("teamplay_teambalanced_player");
		event.SetInt("player", client);
		event.SetInt("team", team);
		SetupTeamSwapBlock(client);
		event.Fire();
	}
	
	LogAction(client, -1, "\"%L\" has been auto-balanced to %s.", client, sTeam);
	if (!g_bSilent)
		PrintToChatAll("\x01\x04[SM]\x01 %t", "TeamChangedAll", sName, sTeam);
	g_aTeams[bImbalanced]=false;
	
	return true;
}

stock void StartForceTimer()
{
	if (g_bBlockDeath)
	{
		return;
	}
	
	if (g_hForceBalanceTimer != null)
	{
		KillTimer(g_hForceBalanceTimer);
		g_hForceBalanceTimer = null;
	}
	
	float fDelay = cvar_MaxUnbalanceTime.FloatValue;
	
	if (1.0 > fDelay)
	{
		return;
	}
	
	g_hForceBalanceTimer = CreateTimer(fDelay, Timer_ForceBalance);
}

public Action Timer_ForceBalance(Handle timer)
{
	g_hForceBalanceTimer = null;
	
	if (TeamsUnbalanced(false))
	{
		if (!g_bSilent)
			PrintToChatAll("\x01\x04[SM]\x01 %t", "ForceMessage");
		BalanceTeams(true);
	}
	
	g_aTeams[bImbalanced] = false;
	return Plugin_Handled;
}

void CheckBalance(bool post=false)
{
	if (!g_bHooked)
	{
		return;
	}
	
	if (g_hCheckTimer != null)
	{
		return;
	}
	
	if (!g_bAutoBalance)
	{
		return;
	}
	
	if (g_bBlockDeath)
	{
		return;
	}
		
	if (post)
	{
		if (g_hCheckTimer == null)
		{
			g_hCheckTimer = CreateTimer(0.5, timer_CheckBalance);
		}
		return;
	}
	if (TeamsUnbalanced())
	{
		if (IsOkToBalance() && !g_aTeams[bImbalanced] && g_hBalanceFlagTimer == null)
		{
			int delay = cvar_BalanceActionDelay.IntValue;
			if (!g_bSilent && delay > 1)
			{
				PrintToChatAll("\x01\x04[SM]\x01 %t", "FlagBalance", delay);
			}
			g_hBalanceFlagTimer = CreateTimer(float(delay), timer_BalanceFlag);
		}
		if (g_RoundState == preGame || g_RoundState == bonusRound || g_RoundState == suddenDeath)
		{
			if (g_hBalanceFlagTimer != null)
			{
				KillTimer(g_hBalanceFlagTimer);
				g_hBalanceFlagTimer = null;
			}
			g_aTeams[bImbalanced] = true;
		}
	}
	else
	{
		if (g_hForceBalanceTimer != null)
		{
			KillTimer(g_hForceBalanceTimer);
			g_hForceBalanceTimer = null;
		}
		g_aTeams[bImbalanced] = false;
		if (g_hBalanceFlagTimer != null)
		{
			KillTimer(g_hBalanceFlagTimer);
			g_hBalanceFlagTimer = null;
		}
		
	}
}

public Action timer_BalanceFlag(Handle timer)
{
	g_hBalanceFlagTimer = null;
	
	if (TeamsUnbalanced())
	{
		StartForceTimer();
		g_aTeams[bImbalanced] = true;
	}
	
	return Plugin_Handled;
}

public Action timer_CheckBalance(Handle timer)
{
	g_hCheckTimer = null;
	CheckBalance();
	
	return Plugin_Handled;
}

stock bool TeamsUnbalanced(bool force=true)
{
	int iDiff = GetAbsValue(GetTeamClientCount(TEAM_RED), GetTeamClientCount(TEAM_BLUE));
	int iForceLimit = cvar_ForceBalanceTrigger.IntValue;
	int iBalanceLimit = cvar_BalanceLimit.IntValue;
	if (iDiff >= iBalanceLimit)
	{
		if (g_RoundState == roundNormal && force && iForceLimit > 1 && iDiff >= iForceLimit)
		{
			BalanceTeams(true);
			if (g_hBalanceFlagTimer != null)
			{
				KillTimer(g_hBalanceFlagTimer);
				g_hBalanceFlagTimer = null;
			}
			
			return false;
		}
		
		return true;
	}
	
	return false;
}

stock void BalanceTeams(bool respawn=true)
{
	if (!TeamsUnbalanced(false) || g_bBlockDeath)
	{
		return;
	}
	
	int team = GetLargerTeam(), counter;
	int smallTeam = GetSmallerTeam();
	int swaps = GetAbsValue(GetTeamClientCount(TEAM_RED), GetTeamClientCount(TEAM_BLUE)) / 2;
		
	int iFatTeam[MAXPLAYERS+1][2];
	for (int i = 1; i <= MaxClients; i++) 
	{
		if (!IsClientInGame(i))
		{
			continue;
		}
		
		if (IsValidSpectator(i))
		{
			iFatTeam[counter][0] = i;
			iFatTeam[counter][1] = 90;
			
			counter++;
		}
		else if (GetClientTeam(i) == team) 
		{
			if (cvar_Preference.BoolValue && g_aPlayers[i][iTeamPreference] == smallTeam && !TF2_IsClientUbered(i))
			{
				iFatTeam[counter][1] = 100;
			}
			else
				iFatTeam[counter][1] = GetPlayerPriority(i);
			iFatTeam[counter][0] = i;
			counter++;
		}
	}	
	
	SortCustom2D(iFatTeam, counter, SortIntsDesc);
	g_bBlockDeath = true;
	for (int i = 0; swaps-- > 0 && i < counter; i++)
	{
		if (iFatTeam[i][0])
		{	
			bool bWasSpec = false;
			if (GetClientTeam(iFatTeam[i][0]) == 1)
			{
				bWasSpec = true;
			}
			
			char clientName[MAX_NAME_LENGTH + 1], sTeam[4];
			GetClientName(iFatTeam[i][0], clientName, 32);
			
			if (team == TEAM_RED)
			{
				sTeam = "Blu";
			}
			else
			{
				sTeam = "Red";
			}
				
			ChangeClientTeam(iFatTeam[i][0], team == TEAM_BLUE ? TEAM_RED : TEAM_BLUE);
			
			if (bWasSpec)
			{
				TF2_SetPlayerClass(iFatTeam[i][0], TFClass_Scout);
			}
			
			if (!g_bSilent)
				PrintToChatAll("\x01\x04[SM]\x01 %t", "TeamChangedAll", clientName, sTeam);
			SetupTeamSwapBlock(iFatTeam[i][0]);
			LogAction(iFatTeam[i][0], -1, "\"%L\" has been force-balanced to %s.", iFatTeam[i][0], sTeam);			
			
			if (respawn)
			{
				CreateTimer(0.5, Timer_BalanceSpawn, GetClientUserId(iFatTeam[i][0]), TIMER_FLAG_NO_MAPCHANGE);
			}
			
			if (!IsFakeClient(iFatTeam[i][0]))
			{				
				Event event = CreateEvent("teamplay_teambalanced_player");
				event.SetInt("player", iFatTeam[i][0]);
				g_aPlayers[iFatTeam[i][0]][iBalanceTime] = GetTime() + (cvar_BalanceTime.IntValue * 60);
				event.SetInt("team", team == TEAM_BLUE ? TEAM_RED : TEAM_BLUE);
				event.Fire();
			}
		}
	}
	g_bBlockDeath = false;
	g_aTeams[bImbalanced] = false;
	return;
}

stock bool IsOkToBalance()
{
	if (g_RoundState == roundNormal)
	{
		int iBalanceTimeLimit = cvar_BalanceTimeLimit.IntValue;
		
		if (iBalanceTimeLimit && g_bRoundIsTimed)
		{
			if ((g_fRoundEndTime - GetGameTime()) < float(iBalanceTimeLimit))
			{
				return false;
			}
		}
		
		float fProgress = cvar_ProgressDisable.FloatValue;
		if (fProgress > 0.0 && GetCartProgress() >= fProgress)
		{
			return false;
		}
		
		return true;
	}
	switch (g_RoundState)
	{
		case suddenDeath:
		{
			return false;
		}
		
		case preGame:
		{
			return false;
		}
		
		case setup:
		{
			return false;
		}
		
		case bonusRound:
		{
			return false;
		}
	}
	return true;
}

public Action Timer_BalanceSpawn(Handle timer, any id)
{
	int client;
	if ((client = (GetClientOfUserId(id))))
	{
		if (!IsPlayerAlive(client))
		{
			TF2_RespawnPlayer(client);
		}
	}
	
	return Plugin_Handled;
}

bool IsClientValidBalanceTarget(int client, bool CalledFromPrio = false)
{
	if (IsClientInGame(client) && IsValidTeam(client))
	{
		if (IsFakeClient(client))
		{
			if (cvar_AbHumanOnly.BoolValue && !TF2_IsClientOnlyMedic(client))
			{
				return false;
			}
			return true;
		}

		if (cvar_Preference.BoolValue)
		{
			int big = GetLargerTeam();
			int pref = g_aPlayers[client][iTeamPreference];
			if (pref && pref != big)
			{
				return true;
			}
		}
		
		if (g_aPlayers[client][iBalanceTime] > GetTime())
		{
			return false;
		}
		
		if (cvar_TeamworkProtect.BoolValue && g_aPlayers[client][iTeamworkTime] >= GetTime())
		{
			return false;
		}
		
		if (TF2_IsClientUberCharged(client) || TF2_IsClientUbered(client) || DoesClientHaveIntel(client))
			return false;
		if (cvar_TopProtect.IntValue && !IsNotTopPlayer(client, GetClientTeam(client)))
		{
			return false;
		}
		
		if (cvar_ProtectOnlyMedic.BoolValue && TF2_IsClientOnlyMedic(client))
		{
			return false;
		}
		
		e_Protection iImmunity = view_as<e_Protection>(cvar_BalanceImmunity.IntValue);
		bool bAdmin = false;
		bool bEngie = false;
		switch (iImmunity)
		{
			case admin:
			{
				bAdmin = true;
			}
			case uberAndBuildings:
			{
				bEngie = true;
			}
			case both:
			{
				bAdmin = true;
				bEngie = true;
			}
		}

		if (bEngie)
		{
			if (TF2_HasBuilding(client))
			{
				return false;
			}
		}

		if (!CalledFromPrio && bAdmin)
		{
			char flags[32];
			bool bSkip = false;
			
			cvar_BalanceAdmFlags.GetString(flags, sizeof(flags));
			bSkip = SkipBalanceCheck();
			if (!bSkip && IsAdmin(client, flags))
			{
				return false;
			}
		}

		switch (CheckBuddySystem(client))
		{
			case 1:
			{
				return false;
			}
			case 2:
			{
				return true;
			}
		}
		
		if (cvar_BalanceDuelImmunity.BoolValue && TF2_IsPlayerInDuel(client))
			return false;
		return true;
	}
	return false;
}

int CheckBuddySystem(int client)
{
	if (g_bUseBuddySystem)
	{
		int buddy;
		
		if ((buddy = g_aPlayers[client][iBuddy]))
		{
			if (GetClientTeam(buddy) == GetClientTeam(client))
			{
				LogAction(-1, 0, "Flagging client %L invalid because of buddy preference", client);
				return 1;
			}
			else if (IsValidTeam(g_aPlayers[client][iBuddy]))
			{
				LogAction(-1, 0, "Flagging client %L valid because of buddy preference", client);
				return 2;
			}
		}		
		if (IsClientBuddy(client))
		{
			return 1;
		}
	}
	return 0;
}

bool SkipBalanceCheck()
{
	if (cvar_BalanceImmunityCheck.FloatValue > 0.0)
	{
		int	iTargets, iImmune, iTotal;
		char flags[32];
		cvar_BalanceAdmFlags.GetString(flags, sizeof(flags));
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && IsValidTeam(i))
			{
				if (IsAdmin(i, flags))
				{
					iImmune++;
				}
				else
				{
					iTargets++;
				}
			}
		}
		if (iImmune)
		{
			float fPercent;
			iTotal = iImmune + iTargets;
			fPercent = float(iImmune) / float(iTotal);
			if (fPercent >= cvar_BalanceImmunityCheck.FloatValue)
			{
				if (!g_bSilent && (GetTime() - g_iImmunityDisabledWarningTime) > 300)
				{
					PrintToChatAll("\x01\x04[SM]\x01 %t", "ImmunityDisabled", RoundFloat(fPercent));
					g_iImmunityDisabledWarningTime = GetTime();
					return true;
				}
			}
		}
	}
	return false;
}

int GetPlayerPriority(int client)
{
	if (IsFakeClient(client))
	{
		return 50;
	}
	int iPriority;
	if (!IsClientValidBalanceTarget(client, false))
		iPriority -=50;
	if (!IsPlayerAlive(client))
	{
		iPriority += 5;
	}
	
	if (cvar_BalanceImmunity.IntValue == 1 || cvar_BalanceImmunity.IntValue == 3)
	{
		char sFlags[32];
		cvar_BalanceAdmFlags.GetString(sFlags, sizeof(sFlags));
		if (IsAdmin(client, sFlags))
			iPriority -=100;
	}
	if (g_aPlayers[client][iBalanceTime] > GetTime())
	{
		iPriority -=20;
	}
	if (GetClientTime(client) < 180)
	{
		iPriority += 5;
	}
	
	switch (CheckBuddySystem(client))
	{
		case 1:
			iPriority -=20;
		case 2:
			iPriority +=100;
	}
	
	return iPriority;
}

bool IsValidTeam(int client)
{
	int team = GetClientTeam(client);
	if (team == TEAM_RED || team == TEAM_BLUE)
	{
		return true;
	}
	
	return false;
}