#pragma option -d2


#include <a_samp>

//SLOTS DEL SERVIDOR
#undef MAX_PLAYERS
#define MAX_PLAYERS 50


/* ==============INCLUDES=============== */
#include <crashdetect>
#include <YSI-Includes\YSI\y_inline>
#include <YSI-Includes\YSI\y_va>
#include <YSI-Includes\YSI\y_stringhash>
#include <YSI-Includes\YSI\y_timers>
#include <YSI-Includes\YSI\y_vehicledata>
#include <a_mysql>
#include <a_mysql_yinline>
#include <streamer>
#include <sscanf2>
#include <Pawn.CMD>
#include <Pawn.Regex>
#include <Pawn.RakNet>
#include <interpolate_weather>
#include <mapandreas>
#define PP_SYNTAX_FOR_LIST
#include <PawnPlus>
/* ==============FIN INCLUDES=============== */
/* ==============INICIO=============== */
#define SERVER_NAME			"VenusCity RP"
#define SERVER_GAMEMODE		"VenusCity"
#define SERVER_HOSTNAME 	"VenusCity RolePlay Android/PC"
#define SERVER_LANGUAGE		"Español - Spanish"
#define SERVER_WEBSITE		"your.website.com"
/* ==============FIN INICIO=============== */
//colores
#define 	COLOR_VERDE                0xFF4A4AFF
enum//dialogs
{
    DIALOG_UNUSED,
    DIALOG_REGISTER,
    DIALOG_AYUDA_GENERAL,
    DIALOG_AYUDA_INFO,
    DIALOG_AYUDA_PERSONAJE,
    DIALOG_AYUDA_PROPIEDADES,
    DIALOG_AYUDA_REPORTES,
    DIALOG_AYUDA_TRABAJOS,
    DIALOG_AYUDA_VEHICULOS,
    DIALOG_AYUDA,
    DIALOG_SHOP_GUNS,   
    DIALOG_LOGIN

};

enum e_Data//datos del jugador
{
	UserID,
	Password[65],
	Salt[17],
	Name[MAX_PLAYER_NAME],
	Money,
	Level,
	Float:POS_X,
	Float:POS_Y,
	Float:POS_Z,
	Float:ANGLE,
	LoginAttempts,
	LoginTimer,
	bool:pLogged
}
new Player[MAX_PLAYERS][e_Data];
enum Guns
{
	WeapID,
	WeaName[64],
	WeapPrice[60],
	WeapAmmo
}
new Shop_g[15][Guns] =
{
	{4, "Knife", 10, 1},
	{8, "Katana", 10, 1},
	{9, "Chainsaw", 100, 1},
	{10, "Purple Dildo", 50, 1},
	{16, "Grenade", 200, 10},
	{18, "Molotov Cocktail", 300, 5},
	{23, "Silenced 9mm", 1000, 50},
	{24, "Desert Eagle", 2000, 100},
	{25, "Shotgun", 2000, 50},
	{26, "Sawnoff Shotgun", 2000, 50},
	{27, "Combat Shotgun", 2000, 50},
	{28, "Uzi", 1000, 100},
	{31, "M4", 2000, 100},
	{34, "Sniper Rifle", 2000, 50},
	{26, "Sawnoff Shotgun", 2000, 50}
};
#define HidePlayerDialog(%1)		ShowPlayerDialog(%1, -1, 0, " ", " ", " ", " ")
new
	MySQL:db_mysql,

	Float:New_User_Pos[4] = {1773.307250, -1896.441040, 13.551166, 270.0};

new IntroServer[][] = {
	"https://cjoint.com/doc/22_09/LIhwlQw21d8_intro-1.mp3"//intro
};
public OnGameModeInit()
{
	SetGameModeText(SERVER_GAMEMODE);
    SendRconCommand("hostname "SERVER_HOSTNAME"...");
    SendRconCommand("language "SERVER_LANGUAGE"");
	SendRconCommand("weburl "SERVER_WEBSITE"");
	SendRconCommand("sleep 1");
	ConnectDatabase();
	LoadMap();//Dese Aqui cargaremos todas las cosas del mapa del servidor/(Negocios, labels, pickups, mapicons ect)

}

public OnGameModeExit()
{
	print("No se establecio una conexion con la base de datos");
	mysql_close(db_mysql);
	return 1;
}
public OnPlayerConnect(playerid)
{
	PlayAudioStreamForPlayer(playerid, IntroServer[random(sizeof IntroServer)]);
	ResetPlayerMoney(playerid);
	for(new i; e_Data:i < e_Data; i++) Player[playerid][e_Data:i] = 0;

	GetPlayerName(playerid, Player[playerid][Name], MAX_PLAYER_NAME);

	new query[128];
	mysql_format(db_mysql, query, sizeof(query),"SELECT * FROM `cuentas` WHERE `Username` = '%e' LIMIT 1", Player[playerid][Name]);
	mysql_tquery(db_mysql, query, "OnAccountCheck", "i", playerid);
	return 1;
}
forward OnAccountCheck(playerid);
public OnAccountCheck(playerid)
{
	if(cache_num_rows())
	{
		cache_get_value_name(0, "Password", Player[playerid][Password], 129);
		cache_get_value_name(0, "Salt", Player[playerid][Salt], 17);
		ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_INPUT, "Iniciar Seccion", "Hola de nuevo, porfavor loguea para continuar a la aventura", "Loguear", "Salir");
		Player[playerid][LoginTimer] = SetTimerEx("OnLoginTimeout", 30 * 1000, false, "d", playerid);
	}else
	{
		ShowPlayerDialog(playerid, DIALOG_REGISTER, DIALOG_STYLE_INPUT, "Cuenta nueva?", "Hola, se bienvenido a nuestro servidor porfavor registrate.", "Registrarse", "Salir");
	}
	return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
	switch(dialogid)
	{
	case DIALOG_SHOP_GUNS:
	{
		if(response)
		{
			if(GetPlayerMoney(playerid) <= Shop_g[listitem][WeapPrice]) return SendClientMessage(playerid, 0xFF0000FF, "AVISO: {FFFFFF}No tienes suficiente dinero.");
			new string[128];
			format(string, sizeof(string), "Aviso: {FFFFFF}%s Compraste el arma $%d. por ", Shop_g[listitem][WeaName], Shop_g[listitem][WeapPrice]);
			SendClientMessage(playerid, 0x66FF00FF, string);
			GivePlayerMoney(playerid, -Shop_g[listitem][WeapPrice]);
			GivePlayerWeapon(playerid, Shop_g[listitem][WeapID], Shop_g[listitem][WeapAmmo]);
		}
		return 1;
	}		
	    case DIALOG_UNUSED: return 1;
	    case DIALOG_LOGIN:
	    {
	        if(!response) return Kick(playerid);

			new hashed_pass[65], query[128];
			SHA256_PassHash(inputtext, Player[playerid][Salt], hashed_pass, 65);
			if(strcmp(hashed_pass, Player[playerid][Password]) == 0)
			{
				mysql_format(db_mysql, query, sizeof(query), "SELECT * FROM `cuentas` WHERE `Username` = '%e' LIMIT 1", Player[playerid][Name]);
				mysql_tquery(db_mysql, query, "OnAccountLoad", "i", playerid);
				KillTimer(Player[playerid][LoginTimer]);
				Player[playerid][LoginTimer] = 0;
			}else
			{
				Player[playerid][LoginAttempts]++;
				if(Player[playerid][LoginAttempts] >= 3)
				{
					ShowPlayerDialog(playerid, DIALOG_UNUSED, DIALOG_STYLE_MSGBOX, "Iniciar Seccion", "Has escrito la clave 3 veces mal seras expulsado", "Aceptar", "");
					Kick(playerid);
					return 1;
				}
				ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_INPUT, "Iniciar Seccion", "Para jugar, debes iniciar sesión\nContraseña incorrecta!", "Loguear", "Salir");
			}
		}
		case DIALOG_REGISTER:
		{
		    if(!response) return Kick(playerid);

		    if(strlen(inputtext) < 6) return ShowPlayerDialog(playerid, DIALOG_REGISTER, DIALOG_STYLE_INPUT, "Register", "Para jugar, debes registrarte.\nSu contraseña debe tener minimo 6 caracteres!", "Registrarse", "Salir");
			for (new i = 0; i < 16; i++) Player[playerid][Salt][i] = random(94) + 33;
			SHA256_PassHash(inputtext, Player[playerid][Salt], Player[playerid][Password], 65);

			new query[256];
			mysql_format(db_mysql, query, sizeof(query), "INSERT INTO `cuentas` (`Username`, `Password`, `Salt`) VALUES ('%e', '%s', '%e')", Player[playerid][Name], Player[playerid][Password], Player[playerid][Salt]);
			mysql_tquery(db_mysql, query, "OnAccountRegister", "i", playerid);
		}
		default: return 0;
	}
	return 1;
}

forward OnAccountLoad(playerid);
public OnAccountLoad(playerid)
{
    cache_get_value_name_int(0, "UserID", Player[playerid][UserID]);
	cache_get_value_name_int(0, "Money", Player[playerid][Money]);
	cache_get_value_name_int(0, "Level", Player[playerid][Level]);	
    cache_get_value_name_float(0, "pos_x", Player[playerid][POS_X]);
	cache_get_value_name_float(0, "pos_y", Player[playerid][POS_Y]);
	cache_get_value_name_float(0, "pos_z", Player[playerid][POS_Z]);
    cache_get_value_name_float(0, "angle", Player[playerid][ANGLE]);

 	SetPlayerScore(playerid, Player[playerid][Level]);
 	GivePlayerMoney(playerid, Player[playerid][Money]);
	Player[playerid][pLogged] = true;
	SendClientMessage(playerid, -1, "Te has conectado correctamente, bienvenido/a de nuevo");
	return 1;
}

forward OnAccountRegister(playerid);
public OnAccountRegister(playerid)
{
    Player[playerid][UserID] = cache_insert_id();
    GivePlayerMoney(playerid, 50000);
    Player[playerid][pLogged] = true;
  	Player[playerid][POS_X] = New_User_Pos[0];
	Player[playerid][POS_Y] = New_User_Pos[1];
	Player[playerid][POS_Z] = New_User_Pos[2];
	Player[playerid][ANGLE] = New_User_Pos[3];  
    return 1;
}
forward OnLoginTimeout(playerid);
public OnLoginTimeout(playerid)
{
	Player[playerid][LoginTimer] = 0;

	ShowPlayerDialog(playerid, DIALOG_UNUSED, DIALOG_STYLE_MSGBOX, "Login", "Se te ha expulsado por demorarte al loguear, reloguea!!.", "Ace", "");
	Kick(playerid);
	return 1;
}
public OnPlayerDisconnect(playerid, reason)
{
	UpdatePlayerData(playerid);
	if(Player[playerid][LoginTimer])
	{
		KillTimer(Player[playerid][LoginTimer]);
		Player[playerid][LoginTimer] = 0;
	}
	return 1;
}

public OnPlayerDeath(playerid, killerid, reason)
{
	return 1;
}

stock UpdatePlayerData(playerid)
{
    if(Player[playerid][pLogged] == true)
	{
		new query[256];
		mysql_format(db_mysql, query, sizeof(query), "UPDATE `cuentas` SET `Money` = %d, `Level` = %d WHERE `ID` = %d", GetPlayerMoney(playerid), GetPlayerScore(playerid), Player[playerid][UserID]);
		mysql_tquery(db_mysql, query);
	}
	return 1;
}

LoadMap(){


 CreateDynamic3DTextLabel("{FF7373}Mercado negro\n{FFFFFF}usa{FF7373}/mercado {FFFFFF}para comprar armas", 0xFFFFFFFF, 2119.059814, -2001.701904, 7.984375, 10.0, .testlos = true, .interiorid = 0, .worldid = 0);

}
ConnectDatabase()
{
	//mysql
	print("[Consola] Conectando a la base de datos...");
	mysql_log(ERROR | WARNING);
	//mysql_log(NONE);

	//db_mysql
	db_mysql = mysql_connect_file("db_mysql.ini");
	if(db_mysql == MYSQL_INVALID_HANDLE || mysql_errno(db_mysql) != 0)
	{
		printf("[Consola] No se pudo conectar con la base de datos");
		SendRconCommand("exit");
	}
	else
	{
	mysql_tquery(db_mysql,  "CREATE TABLE IF NOT EXISTS `cuentas` (\
														`UserID` INT(11) NOT NULL AUTO_INCREMENT,\
														`Username` VARCHAR(24) NOT NULL,\
														`Password` VARCHAR(129) NOT NULL,\
														`Salt` VARCHAR(16) NOT NULL,\
														`Money` INT(11) NOT NULL,\
														`Level` INT(11) NOT NULL,\
														`pos_x` ,\
				                                        `pos_y` ,\
				                                        `pos_z` ,\
			                                            `angle` ,\
														PRIMARY KEY (`UserID`))");
  	printf("[Consola] Base de datos conectada(Datos Generales Cargados)");
	}
	return 1;
}
CMD:comprararmas(playerid, params[])
{
    if(!IsPlayerInRangeOfPoint(playerid, 1.0, 2119.059814, -2001.701904, 7.984375)) return SendClientMessage(playerid, -1,  "No estás en el lugar adecuado.");	
	new string[2048];
	for(new x = 0; x < sizeof(Shop_g); x++)
	{
		format(string, sizeof(string), "%s%s - $%d\n", string, Shop_g[x][WeaName], Shop_g[x][WeapPrice]);
	}
	ShowPlayerDialog(playerid, DIALOG_SHOP_GUNS, DIALOG_STYLE_LIST, "Mercado Negro", string, "Comprar", "{FF0000}Cancelar");
	return 1;
}
CMD:damedinero(playerid, params[])
{
   GivePlayerMoney(playerid, 5000000);
   return 1;
}	
#include "./modules_server/properties.pwn"
#include "./modules_server/maps_server.pwn"