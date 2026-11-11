extends RefCounted
## Acceptance-only stock-gear policy. Not used by player gameplay.
static func actions(run:RefCounted,with_tricks:bool=false)->Dictionary:
	var risk:Array[float]=[0.0,0.0,0.0]
	for e in run.events:
		if e.used or e.kind in ["token","ramp"]:continue
		var d:float=run.event_front(e)-run.distance
		if e.kind=="rail" and d<0 and run.event_position(e)+float(e.get("rail_length",3.0))*0.5>=run.distance:d=0.0
		var eta:float=d/maxf(1.0,run.speed-(float(e.npc_speed) if e.kind=="skater" else 0.0))
		if eta < -0.05 or eta > 1.5:continue
		var weight:float=20.0 if e.kind=="skater" else (10.0 if e.kind=="block" else 2.0)
		for candidate in range(3):
			var crossing:float=move_toward(run.x,float(run.LANES[candidate]),maxf(0.0,eta)*(12.0+run.grip_level*1.2))
			if absf(crossing-float(run.LANES[int(e.lane)]))<1.0:
				risk[candidate]+=weight*(1.6-eta)
	var target:int=run.lane
	var best:float=risk[target]-0.4
	for i in range(3):
		var cost:float=risk[i]+absf(float(i-run.lane))*0.15
		if cost<best:best=cost;target=i
	var jump:=false
	for e in run.events:
		if e.used or int(e.lane)!=target or e.kind not in ["rail","block"]:continue
		var eta:float=(run.event_front(e)-run.distance)/run.speed
		if eta>0 and eta<0.5:jump=true
		if e.kind=="rail" and eta<=0 and run.event_position(e)+float(e.get("rail_length",3.0))*0.5>run.distance:jump=true
	if run.grind>0 and run.grind<0.22:jump=true
	if run.jump<=0 and run.grind<=0 and fmod(run.duration,1.35)<0.025:jump=true
	return {"steer":signi(target-run.lane),"ollie":jump,"flip":with_tricks and run.jump>0.1 and run.jump<run.jump_length*0.8,"push":with_tricks and run.jump<=0 and run.grind<=0 and risk[target]<0.2}
