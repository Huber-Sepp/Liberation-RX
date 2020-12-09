/*
File: clean.sqf
Author:

	Quiksilver

Last modified:

	10/12/2014 ArmA 1.36 by Quiksilver

Description:

	Maintain healthy quantity of some mission objects created during scenarios, including some created by the engine.

    - Abandoned Vehicles (no crew, no owner)
	- Dead bodies
	- Dead vehicles
	- Craters
	- Weapon holders (ground garbage)
	- Mines
	- Static weapons
	- Ruins
	- Orphaned MP Triggers http://feedback.arma3.com/view.php?id=19231
	- Empty Groups

	* Ruins can be excluded by setPos [0,0,0] on them, this script will not touch them in that case. Could be done for JIP/locality reasons, since Ruins can be fiddly with JIP.
	* Note: Please do not place any triggers at nullPos [0,0,0]. This script by default removes all triggers at nullPos.

Instructions:

	ExecVM from initServer.sqf or init.sqf in your mission directory.

	[] execVM "clean.sqf";				// If you put the file in mission directory
	[] execVM "scripts\clean.sqf";		// If you put the file in a folder, in this case called "scripts"
_________________________________________________________________________*/

sleep 15;

if (GRLIB_cleanup_vehicles == 0) exitWith {};

//==================== IGNORE VEHICLES

private _no_cleanup_classnames = GRLIB_vehicle_blacklist;
{
	_no_cleanup_classnames pushback (_x select 0);
} foreach (support_vehicles + static_vehicles + opfor_recyclable);

//==================== HIDDEN-FROM-PLAYERS FUNCTION

_isHidden = {
	params ["_unit", "_dist", "_list"];
	private _c = false;
	if ( ({(( _unit distance2D _x) < _dist)} count _list) == 0 ) then { _c = true };
	_c;
};

//================================================================ CONFIG

deleteManagerPublic = TRUE;						// To terminate script via debug console

private _checkPlayerCount = TRUE;						// dynamic sleep. Set TRUE to have sleep automatically adjust based on # of players.
private _checkFrequencyDefault = 300;					// sleep default
private _checkFrequencyAccelerated = 150;				// sleep accelerated
private _playerThreshold = 4;							// How many players before accelerated cycle kicks in?

private _vehiclesLimit = 30;							// Vehicles Set -1 to disable.
private _vehicleDistCheck = TRUE;						// TRUE to delete any vehicles that are far from players.
private _vehicleDist = 2000;							// Distance (meters) from players that vehicles are not deleted if below max.

private _deadMenLimit = 50;								// Bodies. Set -1 to disable.
private _deadMenDistCheck = TRUE;						// TRUE to delete any bodies that are far from players.
private _deadMenDist = 2000;							// Distance (meters) from players that bodies are not deleted if below max.

private _deadVehiclesLimit = 30;						// Wrecks. Set -1 to disable.
private _deadVehicleDistCheck = TRUE;					// TRUE to delete any destroyed vehicles that are far from players.
private _deadVehicleDist = 2000;						// Distance (meters) from players that destroyed vehicles are not deleted if below max.

private _craterLimit = -1;								// Craters. Set -1 to disable.
private _craterDistCheck = TRUE;						// TRUE to delete any craters that are far from players.
private _craterDist = 2000;								// Distance (meters) from players that craters are not deleted if below max.

private _weaponHolderLimit = 20;						// Weapon Holders. Set -1 to disable.
private _weaponHolderDistCheck = TRUE;					// TRUE to delete any weapon holders that are far from players.
private _weaponHolderDist = 1000;						// Distance (meters) from players that ground garbage is not deleted if below max.

private _minesLimit = 40;								// Land mines. Set -1 to disable.
private _minesDistCheck = TRUE;							// TRUE to delete any mines that are far from ANY UNIT (not just players).
private _minesDist = 2000;								// Distance (meters) from players that land mines are not deleted if below max.

private _staticsLimit = -1;								// Static weapons. Set -1 to disable.
private _staticsDistCheck = TRUE;						// TRUE to delete any static weapon that is far from ANY UNIT (not just players).
private _staticsDist = 2000;							// Distance (meters) from players that static weapons are not deleted if below max.

private _ruinsLimit = 20;								// Ruins. Set -1 to disable.
private _ruinsDistCheck = TRUE;							// TRUE to delete any ruins that are far from players.
private _ruinsDist = 2000;								// Distance (meters) from players that ruins are not deleted if below max.

private _orphanedTriggers = TRUE;						// Clean orphaned triggers in MP.
private _emptyGroups = TRUE;							// Set FALSE to not delete empty groups.

//================================================================ LOOP

while {deleteManagerPublic} do {

	//================================= DEAD MEN
	if (!(_deadMenLimit isEqualTo -1)) then {
		if ((count allDeadMen) > _deadMenLimit) then {
			if (_deadMenDistCheck) then {
				{
					if ([_x,_deadMenDist,(playableUnits + switchableUnits)] call _isHidden) then {
						detach _x;
						deleteVehicle _x;
					};
				} count allDeadMen;
			};

			while {(((count allDeadMen) - _deadMenLimit) > 0)} do {
				_unit = selectRandom allDeadMen;
				detach _unit;
				deleteVehicle _unit;
				sleep 0.5;
			};
		};
	};
	sleep 1;
	//================================= VEHICLES
	if (!(_vehiclesLimit isEqualTo -1)) then {
		_nbVehicles = [vehicles, { alive _x && _x getVariable ["GRLIB_vehicle_owner", ""] == "" && isNull (_x getVariable ["R3F_LOG_est_transporte_par", objNull]) && !(_x getVariable ['R3F_LOG_disabled', true]) && count (crew _x) == 0 && (_x distance lhd) >= 1000 && !(typeOf _x in _no_cleanup_classnames) }] call BIS_fnc_conditionalSelect;
		if ((count (_nbVehicles)) > _vehiclesLimit) then {
			if (_vehicleDistCheck) then {
				{
					if ([_x,_vehicleDist,(playableUnits + switchableUnits)] call _isHidden) then {
						[_x] call clean_vehicle;
						deleteVehicle _x;
					};
				} count (_nbVehicles);
			};

			while {(( (count (_nbVehicles)) - _vehiclesLimit) > 0)} do {
				_veh = selectRandom (_nbVehicles);
				[_veh] call clean_vehicle;
				deleteVehicle _veh;
				sleep 0.5;
			};
		};
	};
	sleep 1;
	//================================= WRECKS
	if (!(_deadVehiclesLimit isEqualTo -1)) then {
		if ((count (allDead - allDeadMen)) > _deadVehiclesLimit) then {
			if (_deadVehicleDistCheck) then {
				{
					if ([_x,_deadVehicleDist,(playableUnits + switchableUnits)] call _isHidden) then {
						[_x] call clean_vehicle;
						deleteVehicle _x;
					};
				} count (allDead - allDeadMen);
			};

			while {(((count (allDead - allDeadMen)) - _deadVehiclesLimit) > 0)} do {
				_veh = selectRandom (allDead - allDeadMen);
				[_veh] call clean_vehicle;
				deleteVehicle _veh;
				sleep 0.5;
			};
		};
	};
	sleep 1;
	//================================= CRATERS
	if (!(_craterLimit isEqualTo -1)) then {
		if ((count (allMissionObjects "CraterLong")) > _craterLimit) then {
			if (_craterDistCheck) then {
				{
					if ([_x,_craterDist,(playableUnits + switchableUnits)] call _isHidden) then {
						deleteVehicle _x;
					};
				} count (allMissionObjects "CraterLong");
			};

			while {(((count (allMissionObjects "CraterLong")) - _craterLimit) > 0)} do {
				deleteVehicle (selectRandom (allMissionObjects "CraterLong"));
				sleep 0.5;
			};
		};
	};
	sleep 1;
	//================================= WEAPON HOLDERS
	if (!(_weaponHolderLimit isEqualTo -1)) then {
		if ((count (allMissionObjects "WeaponHolder")) > _weaponHolderLimit) then {
			if (_weaponHolderDistCheck) then {
				{
					if ([_x,_weaponHolderDist,(playableUnits + switchableUnits)] call _isHidden) then {
						deleteVehicle _x;
					};
				} count (allMissionObjects "WeaponHolder");
			};

			while {(((count (allMissionObjects "WeaponHolder")) - _weaponHolderLimit) > 0)} do {
				deleteVehicle (selectRandom (allMissionObjects "WeaponHolder"));
				sleep 0.5;
			};
		};
	};
	// Object WeaponHolderSimulated can't have zero or negative mass!
	{ if (round (getMass _x) <= 0) then { _x setMass 1 } } forEach (entities "WeaponHolderSimulated");
	sleep 1;
	//================================= MINES
	if (!(_minesLimit isEqualTo -1)) then {
		if ((count allMines) > _minesLimit) then {
			if (_minesDistCheck) then {
				{
					if ([_x,_minesDist,allUnits] call _isHidden) then {
						deleteVehicle _x;
					};
				} count allMines;
			};

			while {(((count allMines) - _minesLimit) > 0)} do {
				deleteVehicle (selectRandom allMines);
				sleep 0.5;
			};
		};
	};
	sleep 1;
	//================================= STATIC WEAPONS
	if (!(_staticsLimit isEqualTo -1)) then {
		if ((count (allMissionObjects "StaticWeapon")) > _staticsLimit) then {
			if (_staticsDistCheck) then {
				{
					if ([_x,_staticsDist,allUnits] call _isHidden) then {
						deleteVehicle _x;
					};
				} count (allMissionObjects "StaticWeapon");
			};

			while {(((count (allMissionObjects "StaticWeapon")) - _staticsLimit) > 0)} do {
				deleteVehicle (selectRandom (allMissionObjects "StaticWeapon"));
				sleep 0.5;
			};
		};
	};
	sleep 1;
	//================================= RUINS
	if (!(_ruinsLimit isEqualTo -1)) then {
		_ruins = [];
		{
			if ((_x distance [0,0,0]) > 100) then {
				0 = _ruins pushBack _x;
				sleep 0.1;
			};
		} count (allMissionObjects "Ruins");

		if ((count _ruins) > _ruinsLimit) then {
			if (_ruinsDistCheck) then {
				{
					if ([_x,_ruinsDist,(playableUnits + switchableUnits)] call _isHidden) then {
						deleteVehicle _x;
					};
				} count (allMissionObjects "Ruins");
			};

			while {(((count _ruins) - _ruinsLimit) > 0)} do {
				_ruins resize (count _ruins - 1);
				deleteVehicle (selectRandom _ruins);
				sleep 0.5;
			};
		};
	};
	sleep 1;
	//================================= ORPHANED MP TRIGGERS.
	if (_orphanedTriggers) then {
		{
			if ((_x distance [0,0,0]) < 1) then {
				deleteVehicle _x;
			};
		} count (allMissionObjects "EmptyDetector");
	};
	sleep 1;
	//================================= EMPTY GROUPS
	if (_emptyGroups) then {
		{
			if ((count units _x) isEqualTo 0) then {
				deleteGroup _x;
			};
		} count allGroups;
	};
    sleep 1;
	//================================= SLEEP
	if (_checkPlayerCount) then {
		if ((count (playableUnits + switchableUnits)) >= _playerThreshold) then {
			sleep _checkFrequencyAccelerated;
		} else {
			sleep _checkFrequencyDefault;
		};
	} else {
		sleep _checkFrequencyDefault;
	};
};