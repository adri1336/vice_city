#include <a_samp>
#include <streamer>

//Vice City Map Limits
#define VICE_CITY_MIN_X 4130.0
#define VICE_CITY_MIN_Y -930.0
#define VICE_CITY_MAX_X 6975.0
#define VICE_CITY_MAX_Y 2665.0

//Minimap Global definitions
#define MINIMAP_MODEL_ID -1500
#define AREA_TYPE_MINIMAP 1 //this must be an unique int in streamer arrayData, use 1 if you don't use streamer data manipulation
#define MINIMAP_UPDATE_INTERVAL 100

//Minimap Textdraws definitions
#define MINIMAP_TEXTDRAW_POS_X 25.0
#define MINIMAP_TEXTDRAW_POS_Y 325.0
#define MINIMAP_TEXTDRAW_SIZE_X 110.0
#define MINIMAP_TEXTDRAW_SIZE_Y 95.0
#define MINIMAP_TEXTDRAW_ICON_SIZE_X 6.4
#define MINIMAP_TEXTDRAW_ICON_SIZE_Y 8.0
#define MINIMAP_TEXTDRAW_BORDER_SIZE 2.0

//Area variables
new 
	vcArea = INVALID_STREAMER_ID, //whole map
	minimapAreas[15] = {INVALID_STREAMER_ID, ...}, //each minimap section
	Float:minimapAreas_Coords[15][4] = //minimap sections limits (minX, minY, maxX, maxY)
	{
		{4130.000000, -930.000000, 5078.333496, -211.000000},   //1
		{5078.333496, -930.000000, 6026.666503, -211.000000},   //2
		{6026.666503, -930.000000, 6975.000000, -211.000000},   //3
		{4130.000000, -211.000000, 5078.333496, 508.000000},    //4
		{5078.333496, -211.000000, 6026.666503, 508.000000},    //5
		{6026.666503, -211.000000, 6975.000000, 508.000000},    //6
		{4130.000000, 508.000000, 5078.333496, 1227.000000},    //7
		{5078.333496, 508.000000, 6026.666503, 1227.000000},    //8
		{6026.666503, 508.000000, 6975.000000, 1227.000000},    //9
		{4130.000000, 1227.000000, 5078.333496, 1946.000000},   //10
		{5078.333496, 1227.000000, 6026.666503, 1946.000000},   //11
		{6026.666503, 1227.000000, 6975.000000, 1946.000000},   //12
		{4130.000000, 1946.000000, 5078.333496, 2665.000000},   //13
		{5078.333496, 1946.000000, 6026.666503, 2665.000000},   //14
		{6026.666503, 1946.000000, 6975.000000, 2665.000000}    //15
	}
;

//Player variables
forward OnVcMinimapRequestUpdate(playerid);
new
	bool:pVcMinimap[MAX_PLAYERS],
	PlayerText:pVcMinimapTextdraws[MAX_PLAYERS][3] = {{PlayerText:INVALID_TEXT_DRAW, ...}, ...},
	pVcMinimapCurrentArea[MAX_PLAYERS],
	pVcMinimapTimer[MAX_PLAYERS] = {-1, ...};

public OnFilterScriptInit()
{
    AddSimpleModel(-1, 19379, MINIMAP_MODEL_ID, "blank.dff", "minimap.txd");
    
    new streamer_info[2];
    streamer_info[0] = AREA_TYPE_MINIMAP;
    streamer_info[1] = 0;
	vcArea = CreateDynamicRectangle(VICE_CITY_MIN_X, VICE_CITY_MIN_Y, VICE_CITY_MAX_X, VICE_CITY_MAX_Y, -1, 0);
	Streamer_SetArrayData(STREAMER_TYPE_AREA, vcArea, E_STREAMER_EXTRA_ID, streamer_info);
	
    for(new i = 0, j = sizeof minimapAreas; i != j; i ++)
	{    
        streamer_info[1] = i + 1;   
		minimapAreas[i] = CreateDynamicRectangle(minimapAreas_Coords[i][0], minimapAreas_Coords[i][1], minimapAreas_Coords[i][2], minimapAreas_Coords[i][3], -1, 0);
		Streamer_SetArrayData(STREAMER_TYPE_AREA, minimapAreas[i], E_STREAMER_EXTRA_ID, streamer_info);
	}

	for(new i = 0; i < MAX_PLAYERS; i ++)
	{
		if(IsPlayerConnected(i))
		CreatePlayerVcMinimap(i);
	}
}

public OnFilterScriptExit()
{
	for(new i = 0; i < MAX_PLAYERS; i ++)
	{
		if(IsPlayerConnected(i) && pVcMinimap[i])
		DestroyPlayerVcMinimap(i);
	}
}

public OnPlayerSpawn(playerid)
{
	if(!pVcMinimap[playerid])
	CreatePlayerVcMinimap(playerid);
}

public OnPlayerDisconnect(playerid, reason)
{
	if(pVcMinimap[playerid])
	DestroyPlayerVcMinimap(playerid);
}

public OnPlayerEnterDynamicArea(playerid, areaid)
{
	if(pVcMinimap[playerid])
	{
		new streamer_info[2];
		Streamer_GetArrayData(STREAMER_TYPE_AREA, areaid, E_STREAMER_EXTRA_ID, streamer_info);
		if(streamer_info[0] == AREA_TYPE_MINIMAP && streamer_info[1] > 0)
		{
			pVcMinimapCurrentArea[playerid] = streamer_info[1];
			
			new td_str[64];
			format(td_str, sizeof td_str, "mdl"#MINIMAP_MODEL_ID":%d", pVcMinimapCurrentArea[playerid]);
			PlayerTextDrawSetString(playerid, pVcMinimapTextdraws[playerid][1], td_str);

			if(pVcMinimapCurrentArea[playerid] == 0) PlayerTextDrawColor(playerid, pVcMinimapTextdraws[playerid][1], 0x95CAFCFF); //water color
			else PlayerTextDrawColor(playerid, pVcMinimapTextdraws[playerid][1], -1);
			PlayerTextDrawShow(playerid, pVcMinimapTextdraws[playerid][1]);
			UpdateVcMinimapPlayerLocation(playerid);
		}
	}
}

public OnPlayerLeaveDynamicArea(playerid, areaid)
{
	if(pVcMinimap[playerid])
	{
		new streamer_info[2];
		Streamer_GetArrayData(STREAMER_TYPE_AREA, areaid, E_STREAMER_EXTRA_ID, streamer_info);
		if(streamer_info[0] == AREA_TYPE_MINIMAP && streamer_info[1] == 0) //player left vc map
		{
			pVcMinimapCurrentArea[playerid] = streamer_info[1];
			
			new td_str[64];
			format(td_str, sizeof td_str, "mdl"#MINIMAP_MODEL_ID":%d", pVcMinimapCurrentArea[playerid]);
			PlayerTextDrawSetString(playerid, pVcMinimapTextdraws[playerid][1], td_str);

			if(pVcMinimapCurrentArea[playerid] == 0) PlayerTextDrawColor(playerid, pVcMinimapTextdraws[playerid][1], 0x95CAFCFF); //water color
			else PlayerTextDrawColor(playerid, pVcMinimapTextdraws[playerid][1], -1);
			PlayerTextDrawShow(playerid, pVcMinimapTextdraws[playerid][1]);
			UpdateVcMinimapPlayerLocation(playerid);
		}
	}
}

public OnVcMinimapRequestUpdate(playerid)
{
	UpdateVcMinimapPlayerLocation(playerid);
}

CreatePlayerVcMinimap(playerid)
{
	if(pVcMinimap[playerid])
	return false;

	//Get player current area
	pVcMinimapCurrentArea[playerid] = 0;
	new player_areas[20];
	GetPlayerDynamicAreas(playerid, player_areas);
	for(new i = 0; i < sizeof player_areas; i ++)
	{
		if(player_areas[i] != INVALID_STREAMER_ID)
		{
			new streamer_info[2];
			Streamer_GetArrayData(STREAMER_TYPE_AREA, player_areas[i], E_STREAMER_EXTRA_ID, streamer_info);
			if(streamer_info[0] == AREA_TYPE_MINIMAP && streamer_info[1] > 0)
			{
				pVcMinimapCurrentArea[playerid] = streamer_info[1];
				break;
			}
		}
	}

	//Minimap Border
	pVcMinimapTextdraws[playerid][0] = CreatePlayerTextDraw(playerid, MINIMAP_TEXTDRAW_POS_X - MINIMAP_TEXTDRAW_BORDER_SIZE, MINIMAP_TEXTDRAW_POS_Y - MINIMAP_TEXTDRAW_BORDER_SIZE, "LD_SPAC:white");
	PlayerTextDrawTextSize(playerid, pVcMinimapTextdraws[playerid][0],
		/*SizeX*/ MINIMAP_TEXTDRAW_SIZE_X + (MINIMAP_TEXTDRAW_BORDER_SIZE * 2.0),
		/*SizeY*/ MINIMAP_TEXTDRAW_SIZE_Y + (MINIMAP_TEXTDRAW_BORDER_SIZE * 2.0));
	PlayerTextDrawAlignment(playerid, pVcMinimapTextdraws[playerid][0], 1);
	PlayerTextDrawColor(playerid, pVcMinimapTextdraws[playerid][0], 255);
	PlayerTextDrawSetShadow(playerid, pVcMinimapTextdraws[playerid][0], 0);
	PlayerTextDrawBackgroundColor(playerid, pVcMinimapTextdraws[playerid][0], 255);
	PlayerTextDrawFont(playerid, pVcMinimapTextdraws[playerid][0], 4);
	PlayerTextDrawSetProportional(playerid, pVcMinimapTextdraws[playerid][0], 0);
	PlayerTextDrawShow(playerid, pVcMinimapTextdraws[playerid][0]);

	//Minimap
	new td_str[64];
	format(td_str, sizeof td_str, "mdl"#MINIMAP_MODEL_ID":%d", pVcMinimapCurrentArea[playerid]);
	pVcMinimapTextdraws[playerid][1] = CreatePlayerTextDraw(playerid, MINIMAP_TEXTDRAW_POS_X, MINIMAP_TEXTDRAW_POS_Y, td_str);
	PlayerTextDrawTextSize(playerid, pVcMinimapTextdraws[playerid][1], MINIMAP_TEXTDRAW_SIZE_X, MINIMAP_TEXTDRAW_SIZE_Y);
	PlayerTextDrawAlignment(playerid, pVcMinimapTextdraws[playerid][1], 1);
	if(pVcMinimapCurrentArea[playerid] == 0) PlayerTextDrawColor(playerid, pVcMinimapTextdraws[playerid][1], 0x95CAFCFF); //water color
	else PlayerTextDrawColor(playerid, pVcMinimapTextdraws[playerid][1], -1);
	PlayerTextDrawSetShadow(playerid, pVcMinimapTextdraws[playerid][1], 0);
	PlayerTextDrawBackgroundColor(playerid, pVcMinimapTextdraws[playerid][1], 255);
	PlayerTextDrawFont(playerid, pVcMinimapTextdraws[playerid][1], 4);
	PlayerTextDrawSetProportional(playerid, pVcMinimapTextdraws[playerid][1], 0);
	PlayerTextDrawShow(playerid, pVcMinimapTextdraws[playerid][1]);

	//Timer
	pVcMinimapTimer[playerid] = SetTimerEx("OnVcMinimapRequestUpdate", MINIMAP_UPDATE_INTERVAL, true, "i", playerid);

	pVcMinimap[playerid] = true;
	return true;
}

DestroyPlayerVcMinimap(playerid)
{
	if(!pVcMinimap[playerid])
	return false;

	if(pVcMinimapTimer[playerid] != -1)
	{
		KillTimer(pVcMinimapTimer[playerid]);
		pVcMinimapTimer[playerid] = -1;
	}

	for(new i, j = sizeof pVcMinimapTextdraws[]; i != j; i ++)
	{
		if(pVcMinimapTextdraws[playerid][i] != PlayerText:INVALID_TEXT_DRAW)
		{
			PlayerTextDrawDestroy(playerid, pVcMinimapTextdraws[playerid][i]);
			pVcMinimapTextdraws[playerid][i] = PlayerText:INVALID_TEXT_DRAW;
		}
	}

	pVcMinimap[playerid] = false;
	return true;
}

UpdateVcMinimapPlayerLocation(playerid)
{
	if(pVcMinimapTextdraws[playerid][2] != PlayerText:INVALID_TEXT_DRAW)
	{
		PlayerTextDrawDestroy(playerid, pVcMinimapTextdraws[playerid][2]);
		pVcMinimapTextdraws[playerid][2] = PlayerText:INVALID_TEXT_DRAW;
	}

	new area = pVcMinimapCurrentArea[playerid];
	if(area > 0)
	{
		new Float:td_x, Float:td_y, Float:pos[3];
		GetPlayerPos(playerid, pos[0], pos[1], pos[2]);
		Vc3dTo2d(MINIMAP_TEXTDRAW_POS_X, MINIMAP_TEXTDRAW_POS_Y, MINIMAP_TEXTDRAW_SIZE_X, MINIMAP_TEXTDRAW_SIZE_Y, pos[0], pos[1], pos[2], td_x, td_y, minimapAreas_Coords[area - 1][0], minimapAreas_Coords[area - 1][1], minimapAreas_Coords[area - 1][2], minimapAreas_Coords[area - 1][3]);

		new Float:angle;
		if(IsPlayerInAnyVehicle(playerid)) GetVehicleZAngle(GetPlayerVehicleID(playerid), angle);
		else GetPlayerFacingAngle(playerid, angle);

		pVcMinimapTextdraws[playerid][2] = CreatePlayerTextDraw(playerid, td_x - (MINIMAP_TEXTDRAW_ICON_SIZE_X / 2.0), td_y - (MINIMAP_TEXTDRAW_ICON_SIZE_Y / 2.0), GetPlayerIconByAngle(angle));
		PlayerTextDrawTextSize(playerid, pVcMinimapTextdraws[playerid][2], MINIMAP_TEXTDRAW_ICON_SIZE_X, MINIMAP_TEXTDRAW_ICON_SIZE_Y);
		PlayerTextDrawFont(playerid, pVcMinimapTextdraws[playerid][2], 4);
		PlayerTextDrawColor(playerid, pVcMinimapTextdraws[playerid][2], 0xCCCCCCFF);
		PlayerTextDrawShow(playerid, pVcMinimapTextdraws[playerid][2]);
	}
}

GetPlayerIconByAngle(Float:angle)
{
	new icon[32], compass = GetCompassByAngle(angle);
	switch(compass)
	{
		case 0: format(icon, sizeof icon, "mdl"#MINIMAP_MODEL_ID":player_icon_n");
		case 1: format(icon, sizeof icon, "mdl"#MINIMAP_MODEL_ID":player_icon_nw");
		case 2: format(icon, sizeof icon, "mdl"#MINIMAP_MODEL_ID":player_icon_w");
		case 3: format(icon, sizeof icon, "mdl"#MINIMAP_MODEL_ID":player_icon_sw");
		case 4: format(icon, sizeof icon, "mdl"#MINIMAP_MODEL_ID":player_icon_s");
		case 5: format(icon, sizeof icon, "mdl"#MINIMAP_MODEL_ID":player_icon_se");
		case 6: format(icon, sizeof icon, "mdl"#MINIMAP_MODEL_ID":player_icon_e");
		case 7: format(icon, sizeof icon, "mdl"#MINIMAP_MODEL_ID":player_icon_ne");
		default: format(icon, sizeof icon, "mdl"#MINIMAP_MODEL_ID":player_icon");
	}
	return icon;
}

Float:FixRotation(Float:rotation, &Float:frotation = 0.0)
{
	frotation = rotation;
	while(frotation < 0.0) frotation += 360.0;
	while(frotation >= 360.0) frotation -= 360.0;
	return frotation;
}

GetCompassByAngle(Float:angle)
{
	new Float:fixed_angle;
	FixRotation(angle, fixed_angle);
	if((fixed_angle >= 337.5 && fixed_angle <= 360.0) || (fixed_angle >= 0.0 && fixed_angle <= 22.5)) return 0; //n
	else if(fixed_angle >= 22.5 && fixed_angle <= 67.5) return 1; //nw
	else if(fixed_angle >= 67.5 && fixed_angle <= 112.5) return 2; //w
	else if(fixed_angle >= 112.5 && fixed_angle <= 157.5) return 3; //sw
	else if(fixed_angle >= 157.5 && fixed_angle <= 202.5) return 4; //s
	else if(fixed_angle >= 202.5 && fixed_angle <= 247.5) return 5; //se
	else if(fixed_angle >= 247.5 && fixed_angle <= 292.5) return 6; //e
	else if(fixed_angle >= 292.5 && fixed_angle <= 337.5) return 7; //ne
	return -1;
}

Vc3dTo2d(Float:map_x, Float:map_y, Float:map_size_x, Float:map_size_y, Float:x, Float:y, Float:z, &Float:td_x, &Float:td_y, Float:minX = VICE_CITY_MIN_X, Float:minY = VICE_CITY_MIN_Y, Float:maxX = VICE_CITY_MAX_X, Float:maxY = VICE_CITY_MAX_Y)
{
	#pragma unused z

	/* Map limits */
	if(x > maxX) x = maxX;
	else if(x < minX) x = minX;

	if(y > maxY) y = maxY;
	else if(y < minY) y = minY;

	/* Calculations */
	new Float:map_width = floatsub(maxX, minX),
		Float:prop_X = floatdiv(map_size_x, map_width),
		Float:mv_X = floatsub(map_width, maxX);
	
	new Float:map_height = floatsub(minY, maxY),
		Float:prop_Y = floatdiv(map_size_y, map_height),
		Float:mv_Y = floatsub(map_height, minY);
	
	/* Conversion */
	x += mv_X;
	y += mv_Y;

	/* Result */
	td_x = map_x + floatmul(prop_X, x),
	td_y = map_y + floatmul(prop_Y, y);
}