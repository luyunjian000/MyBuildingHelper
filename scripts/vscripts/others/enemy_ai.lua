
      		local OrderMoveToTarget = {
				UnitIndex = caster:entindex(), 
				OrderType = DOTA_UNIT_ORDER_ATTACK_TARGET,
				TargetIndex = AllEnemies[i]:entindex(), --Optional.  Only used when targeting units
				AbilityIndex = 0, --Optional.  Only used when casting abilities
				Position = nil, --Optional.  Only used when targeting the ground
				Queue = 0 --Optional.  Used for queueing up abilities
			 }
			-- 执行命令
			ExecuteOrderFromTable(OrderMoveToTarget)

			