params ["_attackedSector", ["_attackInProgress", false]];

if (isNil "hc_battlegroup_on") then {
	hc_battlegroup_on = true
};

if ((GRLIB_endgame == 1) || ((combat_readiness < bg_readiness_min) && !(_attackInProgress))) exitWith {};
diag_log format ["Spawn BattlegGroup at %1", time];

private [ "_bg_groups", "_target_size", "_vehicle_pool", "_selected_opfor_battlegroup" ];
_bg_groups = [];

last_battlegroup_size = 0;
_spawn_marker = "";
if (isNil "_attackedSector") then {
	_spawn_marker = [ GRLIB_spawn_min, GRLIB_spawn_max, false ] call F_findOpforSpawnPoint;
} else {
	if (_attackInProgress) then {
		if (isNil "limit_bg_dist") then {
			limit_bg_dist = 3000
		};
		if (isNil "reinforce_spawn_min") then {
			reinforce_spawn_min = 1000
		};
		_sector_list = sectors_allSectors - blufor_sectors - sectors_tower - [_attackedSector] - active_sectors;
		_spawn_marker = [ limit_bg_dist, _attackedSector, _sector_list, reinforce_spawn_min] call F_getNearestSector;
	} else {
		_spawn_marker = [ GRLIB_spawn_min, GRLIB_spawn_max, false, _attackedSector ] call F_findOpforSpawnPoint;
	};
};
_vehicle_pool = opfor_battlegroup_vehicles;
if (combat_readiness < bg_readiness_min*2) then {
	_vehicle_pool = opfor_battlegroup_vehicles_low_intensity
};

if (_attackInProgress) then {
	_vehicle_pool = opfor_reinforcement_vehicles;
};

if (_spawn_marker != "") then {
	GRLIB_last_battlegroup_time = time;

	_selected_opfor_battlegroup = [];
	_target_size = GRLIB_battlegroup_size * ([] call F_adaptiveOpforFactor) * (sqrt GRLIB_csat_aggressivity);
	if (_target_size >= GRLIB_battlegroup_size * 2) then {
		_target_size = GRLIB_battlegroup_size * 2;
	};
	if (combat_readiness < bg_readiness_min*2) then {
		_target_size = round (_target_size * 0.75)
	};
	if (count allPlayers <= 9) then {
		_target_size = round (_target_size * 0.75)
	};
	while { count _selected_opfor_battlegroup < _target_size } do {
		_selected_opfor_battlegroup pushBack (selectRandom _vehicle_pool);
	};

	if !(_attackInProgress) then {
		[ _spawn_marker ] remoteExec ["remote_call_battlegroup", 0];
	};
	sleep 30;

	{
		_nextgrp = createGroup [GRLIB_side_enemy, true];
		_vehicle = [markerPos _spawn_marker, _x] call F_libSpawnVehicle;
		_vehicle setVariable ["GRLIB_counter_TTL", round(time + 2700)];  // 45 minutes TTL
		//_vehicle setSkill skill_ground_vehicles;
		(crew _vehicle) joinSilent _nextgrp;
		if (isNil "_attackedSector") then {
			[_nextgrp, false] spawn battlegroup_ai;
		} else {
			[_nextgrp, false, _attackedSector] spawn battlegroup_ai;
		};
		{
			_x setVariable ["GRLIB_counter_TTL", round(time + 2700)]
		} forEach (units _nextgrp);
		_bg_groups pushBack _nextgrp;
		if (( _x in opfor_troup_transports ) && ( [] call F_opforCap < GRLIB_battlegroup_cap )) then {
			if (isNil "_attackedSector") then {
				[_vehicle] spawn troup_transport;
			} else {
				[_vehicle, _attackedSector] spawn troup_transport;
			};
		};
		last_battlegroup_size = last_battlegroup_size + 1;
		sleep 2;
	} forEach _selected_opfor_battlegroup;

	sleep 5;
	if ((combat_readiness >= bg_readiness_min) && !(_attackInProgress)) then {
		private _objectivepos = ([markerPos _spawn_marker] call F_getNearestBluforObjective) select 0;

		[_objectivepos, GRLIB_side_enemy] spawn spawn_air;
		[_objectivepos] spawn send_paratroopers;
	};

	sleep 5;

	stats_hostile_battlegroups = stats_hostile_battlegroups + 1;

	{
		if (local _x) then {
			_headless_client = [] call F_lessLoadedHC;
			if ((!isNull _headless_client) && (hc_battlegroup_on)) then {
				_x setGroupOwner (owner _headless_client);
			};
		};
		sleep 3;
	} forEach _bg_groups;
};


if (isNil "bg_readiness_cooldown") then { bg_readiness_cooldown = false; };

if (bg_readiness_cooldown) then {
	if (isNil "combat_readiness_reduction") then {
		combat_readiness_reduction = 1.10
	};
	if !(_attackInProgress) then {
		combat_readiness = round(combat_readiness / combat_readiness_reduction)
	};

	if (combat_readiness < 0) then {
		combat_readiness = 0
	};
};
